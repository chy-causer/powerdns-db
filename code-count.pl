#!/usr/bin/perl
#
##
# Quick and dirty script to see how many lines of Perl
# we have in this module.

use SourceCode::LineCounter::Perl;
use Data::Dumper;

my $counter    = SourceCode::LineCounter::Perl->new;
my $total_counter    = SourceCode::LineCounter::Perl->new;
$total_counter->accumulate(1);

foreach my $file (@ARGV) {
    $counter->count( $file );
    $total_counter->count( $file );
    
    my $total_lines   = $counter->total;
    
    my $pod_lines     = $counter->documentation;
    
    my $code_lines    = $counter->code;
    
    my $comment_lines = $counter->comment;

    my $comment_lines = $counter->blank;
    print Dumper($file, $counter);
}

print Dumper($total_counter);
