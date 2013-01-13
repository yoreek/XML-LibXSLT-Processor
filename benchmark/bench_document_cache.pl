#!/usr/bin/perl

use lib ("../blib/lib", "../blib/arch");
use XML::LibXSLT::Processor;
use XML::LibXSLT;
use XML::LibXML;
use Benchmark qw(:all);

my $source     = XML::LibXML->load_xml(string => '<root/>');
my $xslt       = XML::LibXSLT->new();
my $style_doc  = XML::LibXML->load_xml(location => 'document.xsl');
my $stylesheet = $xslt->parse_stylesheet($style_doc);

my $xsltprocNotCached = XML::LibXSLT::Processor->new(document_caching_enable => 0);
my $xsltprocCached    = XML::LibXSLT::Processor->new(document_caching_enable => 1);

# Warm-up cache
{
    my $result = $xsltprocCached->transform($source, 'document.xsl');
}

cmpthese(10000, {
    'XML::LibXSLT::Processor (Cached)' => sub {
        my $result = $xsltprocCached->transform($source, 'document.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
    'XML::LibXSLT::Processor (Not cached)' => sub {
        my $result = $xsltprocNotCached->transform($source, 'document.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
    'XML::LibXSLT'  => sub {
        my $result = $stylesheet->transform($source);
        my $str = $stylesheet->output_string($result);
        #print $str, "\n";
    },
});
