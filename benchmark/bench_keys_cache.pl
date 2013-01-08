#!/usr/bin/perl

use lib ("../blib/lib", "../blib/arch");
use XML::LibXSLT::Processor;
use XML::LibXML;
use Benchmark qw(:all);

my $source     = XML::LibXML->load_xml(string => '<root/>');
my $xsltproc   = XML::LibXSLT::Processor->new();
my $id         = 'id5000';

print "First run:\n";
timethese(1, {
    'Search by key' => sub {
        my $result = $xsltproc->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Sequential search' => sub {
        my $result = $xsltproc->transform($source, 'search.xsl' => {id => "'$id'", use_key => 0});
        #print $result->output_string();
    },
});

print "\nSecond run:\n";
timethese(1000, {
    'Search by key' => sub {
        my $result = $xsltproc->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Sequential search' => sub {
        my $result = $xsltproc->transform($source, 'search.xsl' => {id => "'$id'", use_key => 0});
        #print $result->output_string();
    },
});
