#!/usr/bin/perl

use lib ("../blib/lib", "../blib/arch");
use XML::LibXSLT::Processor;
use XML::LibXML;
use Benchmark qw(:all);

my $source            = XML::LibXML->load_xml(string => '<root/>');
my $xsltprocNotCached = XML::LibXSLT::Processor->new(stylesheet_caching_enable => 0);
my $xsltprocCached    = XML::LibXSLT::Processor->new(stylesheet_caching_enable => 1);

# Warm-up cache
{
    my $result = $xsltprocCached->transform($source, 'test.xsl');
}

cmpthese(20000, {
    'Not cached' => sub {
        my $result = $xsltprocNotCached->transform($source, 'test.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
    'Cached'  => sub {
        my $result = $xsltprocCached->transform($source, 'test.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
});
