#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"
#include "ppport.h"

#include <libxsltp/xsltp_config.h>
#include <libxsltp/xsltp_core.h>
#include <libxsltp/xsltp.h>

#include <libxslt/imports.h>

struct _TransformResult {
    SV             *processor;
    xsltp_result_t *result;
};
typedef struct _TransformResult TransformResult;

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

#define x_PmmUSEREGISTRY       (x_PROXY_NODE_REGISTRY_MUTEX != NULL)
#define x_PmmREGISTRY          (INT2PTR(xmlHashTablePtr,SvIV(SvRV(get_sv("XML::LibXML::__PROXY_NODE_REGISTRY",0)))))

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

SV* x_PROXY_NODE_REGISTRY_MUTEX = NULL;

const char*
x_PmmNodeTypeName( xmlNodePtr elem ){
    const char *name = "XML::LibXML::Node";

    if ( elem != NULL ) {
        switch ( elem->type ) {
        case XML_ELEMENT_NODE:
            name = "XML::LibXML::Element";
            break;
        case XML_TEXT_NODE:
            name = "XML::LibXML::Text";
            break;
        case XML_COMMENT_NODE:
            name = "XML::LibXML::Comment";
            break;
        case XML_CDATA_SECTION_NODE:
            name = "XML::LibXML::CDATASection";
            break;
        case XML_ATTRIBUTE_NODE:
            name = "XML::LibXML::Attr";
            break;
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
            name = "XML::LibXML::Document";
            break;
        case XML_DOCUMENT_FRAG_NODE:
            name = "XML::LibXML::DocumentFragment";
            break;
        case XML_NAMESPACE_DECL:
            name = "XML::LibXML::Namespace";
            break;
        case XML_DTD_NODE:
            name = "XML::LibXML::Dtd";
            break;
        case XML_PI_NODE:
            name = "XML::LibXML::PI";
            break;
        default:
            name = "XML::LibXML::Node";
            break;
        };
        return name;
    }
    return "";
}

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

ProxyNodePtr
x_PmmNewNode(xmlNodePtr node)
{
    ProxyNodePtr proxy = NULL;

    if ( node == NULL ) {
        xs_warn( "x_PmmNewNode: no node found\n" );
        return NULL;
    }

    if ( node->_private == NULL ) {
        switch ( node->type ) {
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            proxy = (ProxyNodePtr)xmlMalloc(sizeof(struct _DocProxyNode));
            if (proxy != NULL) {
                ((DocProxyNodePtr)proxy)->psvi_status = Pmm_NO_PSVI;
                x_SetPmmENCODING(proxy, XML_CHAR_ENCODING_NONE);
            }
            break;
        default:
            proxy = (ProxyNodePtr)xmlMalloc(sizeof(struct _ProxyNode));
            break;
        }
        if (proxy != NULL) {
            proxy->node  = node;
            proxy->owner   = NULL;
            proxy->count   = 0;
            node->_private = (void*) proxy;
        }
    }
    else {
        proxy = (ProxyNodePtr)node->_private;
    }

    return proxy;
}

SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner )
{
    ProxyNodePtr dfProxy= NULL;
    SV * retval = &PL_sv_undef;
    const char * CLASS = "XML::LibXML::Node";

    if ( node != NULL ) {
#ifdef XML_LIBXML_THREADS
      if( x_PmmUSEREGISTRY )
        SvLOCK(x_PROXY_NODE_REGISTRY_MUTEX);
#endif
        /* find out about the class */
        CLASS = x_PmmNodeTypeName( node );
        xs_warn("x_PmmNodeToSv: return new perl node of class:\n");
        xs_warn( CLASS );

        if ( node->_private != NULL ) {
            dfProxy = x_PmmNewNode(node);
            /* warn(" at 0x%08.8X\n", dfProxy); */
        }
        else {
            dfProxy = x_PmmNewNode(node);
            /* fprintf(stderr, " at 0x%08.8X\n", dfProxy); */
            if ( dfProxy != NULL ) {
                if ( owner != NULL ) {
                    dfProxy->owner = x_PmmNODE( owner );
                    x_PmmREFCNT_inc( owner );
                    /* fprintf(stderr, "REFCNT incremented on owner: 0x%08.8X\n", owner); */
                }
                else {
                   xs_warn("x_PmmNodeToSv:   node contains itself (owner==NULL)\n");
                }
            }
            else {
                xs_warn("x_PmmNodeToSv:   proxy creation failed!\n");
            }
        }

        retval = NEWSV(0,0);
        sv_setref_pv( retval, CLASS, (void*)dfProxy );
#ifdef XML_LIBXML_THREADS
    if( x_PmmUSEREGISTRY )
        x_PmmRegistryREFCNT_inc(dfProxy);
#endif
        x_PmmREFCNT_inc(dfProxy);
        /* fprintf(stderr, "REFCNT incremented on node: 0x%08.8X\n", dfProxy); */

        switch ( node->type ) {
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            if ( ((xmlDocPtr)node)->encoding != NULL ) {
                x_SetPmmENCODING(dfProxy, (int)xmlParseCharEncoding( (const char*)((xmlDocPtr)node)->encoding ));
            }
            break;
        default:
            break;
        }
#ifdef XML_LIBXML_THREADS
      if( x_PmmUSEREGISTRY )
        SvUNLOCK(x_PROXY_NODE_REGISTRY_MUTEX);
#endif
    }
    else {
        xs_warn( "x_PmmNodeToSv: no node found!\n" );
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

BOOT:
    xsltp_global_init();

void
END()
    CODE:
        xsltp_global_cleanup();

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

        dXCPT;
        XCPT_TRY_START
        {
            /* parse parameters */
            if (items > 1) {
                if ((items - 1) % 2 != 0) {
                    croak("Odd number of parameters in new()");
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
                        if (processor->profiler_repeat < 1) {
                            processor->profiler_repeat = 1;
                        }
                    }
                    else {
                        croak("Invalid parameter '%s'", p);
                    }
                }

                if (processor->profiler_enable) {
                    processor->profiler = xsltp_profiler_create(processor);
                    if (processor->profiler == NULL) {
                        croak("Failed to create profiler");
                    }
                }
            }
        } XCPT_TRY_END

        XCPT_CATCH
        {
            xsltp_destroy(processor);
            XCPT_RETHROW;
        }

        RETVAL = processor;
    OUTPUT:
        RETVAL

TransformResult *
transform(processor, xml, ...)
        xsltp_t            *processor;
        SV                 *xml;
    PREINIT:
        char                  *buf, *key;
        int                    i, last_param, len;
        I32                    keylen;
        STRLEN                 buf_len;
        xsltp_transform_ctxt_t transform_ctxt[XSLTP_MAX_TRANSFORMATIONS + 1];
        TransformResult       *transform_result;
        SV                    *params, *value;
        HV                    *hv;
        xmlDocPtr              xml_doc, tmp_doc = NULL;
        xsltp_result_t        *result;
    CODE:
        /* parse parameters */
        if (items < 3) {
            croak("Not enough parameters in transform()");
        }
        if (items > (XSLTP_MAX_TRANSFORMATIONS * 2 + 2)) {
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
            transform_ctxt[(i - 2) / 2    ].stylesheet = (char *) SvPV(ST(i), PL_na);
            transform_ctxt[(i - 2) / 2 + 1].stylesheet = NULL;

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
                        if (len > (XSLTP_MAX_TRANSFORMATIONS_PARAMS - 1)) {
                            croak("Too many parameters in transform()");
                        }

                        hv_iterinit(hv);
                        while ((value = hv_iternextsv(hv, &key, &keylen))) {
                            transform_ctxt[(i - 2) / 2].params[last_param++] = key;
                            transform_ctxt[(i - 2) / 2].params[last_param++] = SvPV_nolen(value);
                        }
                    }
                }
            }

            transform_ctxt[(i - 2) / 2].params[last_param] = 0;
        }

        /* transform */
        result = xsltp_transform_multi(processor, transform_ctxt, xml_doc);

        if (tmp_doc != NULL) {
            xmlFreeDoc(tmp_doc);
        }

        if (result == NULL) {
            croak("Failed to transform\n");
        }

        transform_result = malloc(sizeof(TransformResult));
        if (transform_result == NULL) {
            xsltp_result_destroy(result);
            croak("Malloc error in transform()");
        }

        transform_result->result    = result;
        transform_result->processor = (void *) SvRV(ST(0));
        SvREFCNT_inc(transform_result->processor);

        RETVAL = transform_result;
    OUTPUT:
        RETVAL

void
clean(processor)
        xsltp_t *processor;
    CODE:
        xsltp_stylesheet_parser_cache_clean(processor->stylesheet_parser->stylesheet_parser_cache, processor->keys_cache);
        xsltp_document_parser_cache_clean(processor->document_parser->cache, processor->keys_cache);

void
DESTROY(processor)
        xsltp_t *processor;
    CODE:
        xsltp_destroy(processor);

MODULE = XML::LibXSLT::Processor PACKAGE = XML::LibXSLT::Processor::Result

PROTOTYPES: DISABLE

SV *
output_string(transform_result)
        TransformResult    *transform_result;
    PREINIT:
        xsltp_result_t     *result;
        SV                 *results;
        xmlOutputBufferPtr  output;
        const xmlChar      *encoding = NULL;
        xmlCharEncodingHandlerPtr encoder = NULL;
    CODE:
        result = transform_result->result;

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

SV *
profiler_result(transform_result)
        TransformResult         *transform_result;
    PREINIT:
        xsltp_profiler_result_t *profiler_result;
        xmlDocPtr                doc_copy;
    CODE:
        profiler_result = transform_result->result->profiler_result;
        if (profiler_result == NULL || profiler_result->doc == NULL) {
            XSRETURN_UNDEF;
        }

        doc_copy = xmlCopyDoc(profiler_result->doc, 1);
        if (doc_copy->URL == NULL) {
          doc_copy->URL = xmlStrdup(profiler_result->doc->URL);
        }

        RETVAL = x_PmmNodeToSv((xmlNodePtr) doc_copy, NULL);
    OUTPUT:
        RETVAL

void
output_fh(transform_result, fh)
        TransformResult    *transform_result;
        void               *fh;
    PREINIT:
        xsltp_result_t            *result;
        xmlOutputBufferPtr         output;
        const xmlChar             *encoding = NULL;
        xmlCharEncodingHandlerPtr  encoder = NULL;
        MAGIC                     *mg;
        PerlIO                    *fp;
        SV                        *obj;
        GV                        *gv = (GV *)fh;
        IO                        *io = GvIO(gv);
    CODE:
        result = transform_result->result;

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
output_file(transform_result, filename)
        TransformResult    *transform_result;
        char               *filename;
    PREINIT:
        xsltp_result_t     *result;
    CODE:
        result = transform_result->result;

        if (xsltp_result_save_to_file(result, filename) == -1) {
            croak("Output to file failed");
        }

SV *
stylesheet_created(transform_result)
        TransformResult    *transform_result;
    PREINIT:
        xsltp_result_t     *result;
    CODE:
        result = transform_result->result;

        RETVAL = newSViv(result->xsltp_stylesheet->created);
    OUTPUT:
        RETVAL

void
DESTROY(transform_result)
        TransformResult    *transform_result;
    CODE:
        xsltp_result_destroy(transform_result->result);
        SvREFCNT_dec(transform_result->processor);
        free(transform_result);
