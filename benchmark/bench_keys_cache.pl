#!/usr/bin/perl

use lib ("../blib/lib", "../blib/arch");
use XML::LibXSLT::Processor;
use XML::LibXML;
use Benchmark qw(:all);

my $source            = XML::LibXML->load_xml(string => '<root/>');
my $xsltprocCached    = XML::LibXSLT::Processor->new(keys_caching_enable => 1);
my $xsltprocNotCached = XML::LibXSLT::Processor->new(keys_caching_enable => 0);
my $id                = 'id5000';

print "First run:\n";
cmpthese(1, {
    'Search by key (cached)' => sub {
        my $result = $xsltprocCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Search by key (not cached)' => sub {
        my $result = $xsltprocNotCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Sequential search' => sub {
        my $result = $xsltprocCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 0});
        #print $result->output_string();
    },
});

print "\nSecond run:\n";
cmpthese(1000, {
    'Search by key (cached)' => sub {
        my $result = $xsltprocCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Search by key (not cached)' => sub {
        my $result = $xsltprocNotCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 1});
        #print $result->output_string();
    },
    'Sequential search' => sub {
        my $result = $xsltprocCached->transform($source, 'search.xsl' => {id => "'$id'", use_key => 0});
        #print $result->output_string();
    },
});
