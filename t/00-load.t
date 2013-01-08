#!/use/bin/perl

use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('XML::LibXSLT::Processor') };

diag( "Testing XML::LibXSLT::Processor $XML::LibXSLT::Processor::VERSION, Perl $], $^X" );
