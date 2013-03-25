#!/usr/bin/perl

use lib ("../../blib/lib", "../../blib/arch");
use XML::LibXML;
use XML::LibXSLT::Processor;

my $source   = XML::LibXML->load_xml(location => 'small.xml');
my $xsltproc = XML::LibXSLT::Processor->new(
    profiler_enable     => 1,
    profiler_repeat     => 100,
    profiler_stylesheet => 'profiler.xsl',
);

my $result = $xsltproc->transform($source, 'test.xsl' => {param1 => 'value1', param2 => 'value2'});
print $result->output_string();
