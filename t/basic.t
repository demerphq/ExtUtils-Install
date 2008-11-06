#!/usr/bin/perl -w

# This test puts MakeMaker through the paces of a basic perl module
# build, test and installation of the Big::Fat::Dummy module.

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

# The test logic is shared between MakeMaker and Install
# because in MakeMaker we test aspects that we are uninterested
# in with Install.pm, however MakeMaker needs to know if it 
# accidentally breaks Install. So we have this two stage test file
# thing happening.

# This version is distinct to Install alone.

use vars qw/$TESTS $TEST_INSTALL_ONLY/;

$::TESTS= 55;
$::TEST_INSTALL_ONLY= 1;

(my $file=$0)=~s/\.t$/.pl/;
do $file;

#$file=~s/\.pl$/_finish.pl/;
#do $file;