#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"
#include "ppport.h"

#include <libxsltp/xsltp_config.h>
#include <libxsltp/xsltp_core.h>
#include <libxsltp/xsltp.h>

#include <libxslt/imports.h>

#define MAX_TRANSFORMATIONS        16
#define MAX_TRANSFORMATIONS_PARAMS 254

struct _TransformCtxt {
    char *stylesheet;
    char *params[MAX_TRANSFORMATIONS_PARAMS + 1];
};
typedef struct _TransformCtxt TransformCtxt;

#define Pmm_NO_PSVI 0
#define Pmm_PSVI_TAINTED 1

struct _ProxyNode {
    xmlNodePtr node;
    xmlNodePtr owner;
    int count;
};

struct _DocProxyNode {
    xmlNodePtr node;
    xmlNodePtr owner;
    int count;
    int encoding; /* only used for proxies of xmlDocPtr */
    int psvi_status; /* see below ... */
};

/* helper type for the proxy structure */
typedef struct _DocProxyNode DocProxyNode;
typedef struct _ProxyNode ProxyNode;

/* pointer to the proxy structure */
typedef ProxyNode* ProxyNodePtr;
typedef DocProxyNode* DocProxyNodePtr;

/* this my go only into the header used by the xs */
#define SvPROXYNODE(x) (INT2PTR(ProxyNodePtr,SvIV(SvRV(x))))
#define PmmPROXYNODE(x) (INT2PTR(ProxyNodePtr,x->_private))
#define SvNAMESPACE(x) (INT2PTR(xmlNsPtr,SvIV(SvRV(x))))

#define x_PmmREFCNT(node)      node->count
#define x_PmmREFCNT_inc(node)  node->count++
#define x_PmmNODE(xnode)       xnode->node
#define x_PmmOWNER(node)       node->owner
#define x_PmmOWNERPO(node)     ((node && x_PmmOWNER(node)) ? (ProxyNodePtr)x_PmmOWNER(node)->_private : node)

#define x_PmmENCODING(node)    ((DocProxyNodePtr)(node))->encoding
#define x_PmmNodeEncoding(node) ((DocProxyNodePtr)(node->_private))->encoding

#define x_SetPmmENCODING(node,code) x_PmmENCODING(node)=(code)
#define x_SetPmmNodeEncoding(node,code) x_PmmNodeEncoding(node)=(code)

#define x_PmmSvNode(n) x_PmmSvNodeExt(n,1)

ProxyNodePtr
x_PmmNewNode(xmlNodePtr node);

ProxyNodePtr
x_PmmNewFragment(xmlDocPtr document);

SV*
x_PmmCreateDocNode( unsigned int type, ProxyNodePtr pdoc, ...);

int
x_PmmREFCNT_dec( ProxyNodePtr node );

SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner );

#ifdef XS_WARNINGS
#define xs_warn(string) warn(string)
/* #define xs_warn(string) fprintf(stderr, string) */
#else
#define xs_warn(string)
#endif

/* extracts the libxml2 node from a perl reference
 */

xmlNodePtr
x_PmmSvNodeExt( SV* perlnode, int copy )
{
    xmlNodePtr retval = NULL;
    ProxyNodePtr proxy = NULL;

    if ( perlnode != NULL && perlnode != &PL_sv_undef ) {
        if ( sv_derived_from(perlnode, "XML::LibXML::Node")  ) {
            proxy = SvPROXYNODE(perlnode);
            if ( proxy != NULL ) {
                xs_warn( "x_PmmSvNodeExt:   is a xmlNodePtr structure\n" );
                retval = x_PmmNODE( proxy ) ;
            }

            if ( retval != NULL
                 && ((ProxyNodePtr)retval->_private) != proxy ) {
                xs_warn( "x_PmmSvNodeExt:   no node in proxy node\n" );
                x_PmmNODE( proxy ) = NULL;
                retval = NULL;
            }
        }
    }

    return retval;
}

int
Processor_write_scalar(void * context, const char * buffer, int len) {
    SV * scalar;

    scalar = (SV *)context;

    sv_catpvn(scalar, (const char*)buffer, len);

    return len;
}

int
Processor_write_handler(void *fp, char *buffer, int len)
{
    if ( buffer != NULL && len > 0)
        PerlIO_write(fp, buffer, len);

    return len;
}

int
Processor_write_tied_handler(void *obj, char *buffer, int len)
{
    if ( buffer != NULL && len > 0) {
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs((SV *)obj);
        PUSHs(sv_2mortal(newSVpv(buffer, len)));
        PUTBACK;

        call_method("PRINT", G_SCALAR);

        FREETMPS;
        LEAVE;
    }

    return len;
}

int
Processor_close_handler(void *fh)
{
    return 1;
}

MODULE = XML::LibXSLT::Processor PACKAGE = XML::LibXSLT::Processor

PROTOTYPES: DISABLE

xsltp_t *
new(class = "XML::LibXSLT::Processor", ...)
        char *class;
    PREINIT:
        xsltp_t *processor;
        int      i;
        char    *p;
        SV      *v;
    CODE:
        if ((processor = xsltp_create()) == NULL) {
            croak("Malloc error in new()");
        }

        /* parse parameters */
        if (items > 1) {
            if ((items - 1) % 2 != 0) {
                croak("Odd parameters in new()");
            }
            for (i = 1; i < items; i = i + 2) {
                if (!SvOK(ST(i))) {
                    croak("Parameter name is undefined");
                }

                p = (char *) SvPV(ST(i), PL_na);
                v = ST(i + 1);
                if (!SvOK(v)) {
                    croak("Parameter '%s' is undefined", p);
                }

                if (strcmp(p, "stylesheet_max_depth") == 0) {
                    processor->stylesheet_max_depth = SvIV(v);
                }
                else if (strcmp(p, "stylesheet_caching_enable") == 0) {
                    processor->stylesheet_caching_enable = SvIV(v);
                }
                else if (strcmp(p, "document_caching_enable") == 0) {
                    processor->document_caching_enable = SvIV(v);
                }
                else if (strcmp(p, "keys_caching_enable") == 0) {
                    processor->keys_caching_enable = SvIV(v);
                }
                else if (strcmp(p, "profiler_enable") == 0) {
                    processor->profiler_enable = SvIV(v);
                }
                else if (strcmp(p, "profiler_stylesheet") == 0) {
                    processor->profiler_stylesheet = SvPV_nolen(v);
                }
                else if (strcmp(p, "profiler_repeat") == 0) {
                    processor->profiler_repeat = SvIV(v);
                }
                else {
                    croak("Invalid parameter '%s'", p);
                }
            }
        }

        RETVAL = processor;
    OUTPUT:
        RETVAL

xsltp_result_t *
transform(processor, xml, ...)
        xsltp_t            *processor;
        SV                 *xml;
    PREINIT:
        char               *buf, *key;
        int                 keylen, i, last_param, len;
        STRLEN              buf_len;
        TransformCtxt       transforms[MAX_TRANSFORMATIONS + 1];
        SV                 *params, *value;
        HV                 *hv;
        xmlDocPtr           xml_doc, tmp_doc = NULL;
        xsltp_result_t     *result;
    CODE:
        /* parse parameters */
        if (items < 3) {
            croak("Not enough parameters in transform()");
        }
        if (items > (MAX_TRANSFORMATIONS * 2 + 2)) {
            croak("Too many parameters in transform()");
        }

        if (xml == NULL || xml == &PL_sv_undef) {
            croak("XML document is undefined");
        }
        if (sv_derived_from(xml, "XML::LibXML::Node")) {
            xml_doc = (xmlDocPtr) x_PmmSvNode(xml);
            if (xml_doc == NULL) {
                XSRETURN_UNDEF;
            }
        }
        else {
            buf = SvPV(xml, buf_len);
            if (buf[0] == '<') {
                /* string */
                xml_doc = tmp_doc = xmlReadMemory(buf, buf_len, "noname.xml", NULL, 0);
                if (xml_doc == NULL) {
                    croak("Failed to parse XML document\n");
                }
            }
            else {
                /* file */
                xml_doc = tmp_doc = xmlParseFile(buf);
                if (xml_doc == NULL) {
                    croak("Failed to parse XML document\n");
                }
            }
        }

        for (i = 2; i < items; i = i + 2) {
            transforms[(i - 2) / 2].stylesheet = (char *) SvPV(ST(i), PL_na);
            transforms[(i - 2) / 2 + 1].stylesheet = 0;

            last_param = 0;
            if ((i + 1) < items) {
                params = ST(i + 1);
                if (SvTYPE(params) != SVt_NULL) {
                    if (!SvROK(params)) {
                        croak("Parameter is not reference\n");
                    }

                    hv  = (HV *) SvRV(params);
                    if (SvTYPE(hv) != SVt_PVHV) {
                        croak("Parameter is not hash reference\n");
                    }

                    len = HvUSEDKEYS(hv);
                    if (len > 0) {
                        if (len > (MAX_TRANSFORMATIONS_PARAMS - 1)) {
                            croak("Too many parameters in transform()");
                        }

                        hv_iterinit(hv);
                        while ((value = hv_iternextsv(hv, &key, &keylen))) {
                            transforms[(i - 2) / 2].params[last_param++] = key;
                            transforms[(i - 2) / 2].params[last_param++] = SvPV_nolen(value);
                        }
                    }
                }
            }

            transforms[(i - 2) / 2].params[last_param] = 0;
        }

        /* transform */
        result = NULL;
        for (i = 0; i < MAX_TRANSFORMATIONS; i++) {
            if (transforms[i].stylesheet == 0) {
                break;
            }

            if (result != NULL) {
                xml_doc = result->doc;
                result->doc = NULL;
                xsltp_result_destroy(result);
            }

            result = xsltp_transform(processor, transforms[i].stylesheet,
                xml_doc, (const char **) transforms[i].params);

            if (result == NULL) {
                croak("Failed to transform\n");
            }
        }
        if (tmp_doc != NULL) {
            xmlFreeDoc(tmp_doc);
        }

        RETVAL = result;
    OUTPUT:
        RETVAL

void
DESTROY(processor)
        xsltp_t *processor;
    CODE:
        xsltp_destroy(processor);

MODULE = XML::LibXSLT::Processor PACKAGE = XML::LibXSLT::Processor::Result

PROTOTYPES: DISABLE

SV *
output_string(result)
        xsltp_result_t     *result;
    PREINIT:
        SV                 *results;
        xmlOutputBufferPtr  output;
        const xmlChar      *encoding = NULL;
        xmlCharEncodingHandlerPtr encoder = NULL;
    CODE:
        XSLT_GET_IMPORT_PTR(encoding, result->xsltp_stylesheet->stylesheet, encoding)
        if (encoding != NULL) {
            encoder = xmlFindCharEncodingHandler((char *)encoding);
            if ((encoder != NULL) &&
                (xmlStrEqual((const xmlChar *)encoder->name,
                          (const xmlChar *) "UTF-8"))) {
                encoder = NULL;
            }
        }
        results = newSVpv("", 0);
        output = xmlOutputBufferCreateIO(
            (xmlOutputWriteCallback) Processor_write_scalar,
            (xmlOutputCloseCallback) Processor_close_handler,
            (void *) results,
            encoder
        );
        if (xsltp_result_save(result, output) == -1) {
            croak("Output to scalar failed");
        }
        xmlOutputBufferClose(output);

        RETVAL = results;
    OUTPUT:
        RETVAL

void
output_fh(result, fh)
        xsltp_result_t     *result;
        void               *fh;
    PREINIT:
        xmlOutputBufferPtr         output;
        const xmlChar             *encoding = NULL;
        xmlCharEncodingHandlerPtr  encoder = NULL;
        MAGIC                     *mg;
        PerlIO                    *fp;
        SV                        *obj;
        GV                        *gv = (GV *)fh;
        IO                        *io = GvIO(gv);
    CODE:
        XSLT_GET_IMPORT_PTR(encoding, result->xsltp_stylesheet->stylesheet, encoding)
        if (encoding != NULL) {
            encoder = xmlFindCharEncodingHandler((char *)encoding);
            if ((encoder != NULL) &&
                (xmlStrEqual((const xmlChar *)encoder->name,
                          (const xmlChar *) "UTF-8"))) {
                encoder = NULL;
            }
        }

        if (io && (mg = SvTIED_mg((SV *)io, PERL_MAGIC_tiedscalar))) {
            /* tied handle */
            obj = SvTIED_obj(MUTABLE_SV(io), mg);

            output = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) Processor_write_tied_handler,
                (xmlOutputCloseCallback) Processor_close_handler,
                obj,
                encoder
            );
        }
        else {
            /* simple handle */
            fp = IoOFP(io);

            output = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) Processor_write_handler,
                (xmlOutputCloseCallback) Processor_close_handler,
                fp,
                encoder
            );
        }

        if (xsltp_result_save(result, output) == -1) {
            croak("Output to scalar failed");
        }

        xmlOutputBufferClose(output);

void
output_file(result, filename)
        xsltp_result_t     *result;
        char               *filename;
    CODE:
        if (xsltp_result_save_to_file(result, filename) == -1) {
            croak("Output to file failed");
        }

void
DESTROY(result)
        xsltp_result_t *result;
    CODE:
        xsltp_result_destroy(result);
