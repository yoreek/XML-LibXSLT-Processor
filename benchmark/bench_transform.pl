#!/usr/bin/perl

use lib ("../blib/lib", "../blib/arch");
use XML::LibXSLT::Processor;
use XML::LibXSLT;
use XML::LibXML;
use Benchmark qw(:all);

my $source     = XML::LibXML->load_xml(location => 'small.xml');
my $xslt       = XML::LibXSLT->new();
my $style_doc  = XML::LibXML->load_xml(location => 'test.xsl');
my $stylesheet = $xslt->parse_stylesheet($style_doc);

my $xsltproc   = XML::LibXSLT::Processor->new();

# Warm-up cache
{
    my $result = $xsltproc->transform($source, 'test.xsl');
}

print "Test small xml:\n";
cmpthese(10000, {
    'XML::LibXSLT::Processor' => sub {
        my $result = $xsltproc->transform($source, 'test.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
    'XML::LibXSLT'  => sub {
        my $result = $stylesheet->transform($source);
        my $str = $stylesheet->output_string($result);
        #print $str, "\n";
    },
});

$source = XML::LibXML->load_xml(location => 'big.xml');
print "\nTest big xml:\n";
cmpthese(2000, {
    'XML::LibXSLT::Processor' => sub {
        my $result = $xsltproc->transform($source, 'test.xsl');
        my $str = $result->output_string();
        #print $str, "\n";
    },
    'XML::LibXSLT'  => sub {
        my $result = $stylesheet->transform($source);
        my $str = $stylesheet->output_string($result);
        #print $str, "\n";
    },
});
