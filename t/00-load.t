#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch");

use Test::More tests => 1;
BEGIN { use_ok('XML::LibXSLT::Processor') };

diag( "Testing XML::LibXSLT::Processor $XML::LibXSLT::Processor::VERSION, Perl $], $^X" );
