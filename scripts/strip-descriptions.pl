#!/usr/bin/env perl
use strict;
use warnings;

use File::Find;
use File::Temp qw(tempfile);
use FindBin qw($RealBin);
use JSON::PP qw(decode_json);

if (@ARGV != 1 || !-d $ARGV[0]) {
    print STDERR "usage: perl strip-descriptions.pl PATH_TO_CRD_TEMPLATES\n";
    exit 2;
}
my $directory = $ARGV[0];

my $patterns_path = "$RealBin/strip-descriptions.json";
open my $patterns_file, '<:raw', $patterns_path
    or die "error: cannot read $patterns_path: $!\n";
local $/;
my $patterns_json = <$patterns_file>;
close $patterns_file or die "error: cannot close $patterns_path: $!\n";

my $patterns = decode_json($patterns_json);
die "error: description patterns must be a nonempty array\n"
    if ref($patterns) ne 'ARRAY' || !@$patterns;

my @compiled_patterns;
for my $index (0 .. $#$patterns) {
    my $pattern = $patterns->[$index];
    die "error: description pattern " . ($index + 1) . " must be a nonempty string\n"
        if !defined($pattern) || ref($pattern) || $pattern eq '';
    my $compiled = eval { qr/\A(?:$pattern)\z/s };
    die "error: invalid description pattern " . ($index + 1) . ": $@" if $@;
    push @compiled_patterns, $compiled;
}

sub indentation {
    my ($line) = @_;
    return length($1) if $line =~ /\A([ \t]*)/;
    return 0;
}

sub normalize_whitespace {
    my ($text) = @_;
    $text =~ s/\s+/ /g;
    $text =~ s/\A | \z//g;
    return $text;
}

sub matches_description {
    my ($text) = @_;
    my $normalized = normalize_whitespace($text);
    for my $pattern (@compiled_patterns) {
        return 1 if $normalized =~ $pattern;
    }
    return 0;
}

sub strip_descriptions {
    my ($contents) = @_;
    my @lines = split /(?<=\n)/, $contents;
    my @result;
    my $removed = 0;

    for (my $index = 0; $index < @lines; $index++) {
        my $line = $lines[$index];
        if ($line !~ /\A([ \t]*)description:[ \t]*(.*?)(?:\r?\n)?\z/) {
            push @result, $line;
            next;
        }

        my $indent = length($1);
        my $value = $2;
        my $end = $index;
        my $block_scalar = $value =~ /\A[|>](?:[+-]?[1-9]?|[1-9]?[+-]?)(?:[ \t]+#.*)?\z/;
        if ($block_scalar) {
            $value = '';
            for (my $child = $index + 1; $child < @lines; $child++) {
                my $child_line = $lines[$child];
                my $content = $child_line;
                $content =~ s/\r?\n\z//;
                last if $content =~ /\S/ && indentation($content) <= $indent;
                $value .= $child_line;
                $end = $child;
            }
        } else {
            $value =~ s/\A(['"])(.*)\1\z/$2/s;
        }

        if (matches_description($value)) {
            $removed++;
            $index = $end;
        } else {
            push @result, @lines[$index .. $end];
            $index = $end;
        }
    }

    return (join('', @result), $removed);
}

my @files;
find(
    {
        no_chdir => 1,
        wanted   => sub {
            return if -d $_;
            return if $_ !~ /\.ya?ml\z/i;
            die "error: $_: expected a regular YAML file, not a symlink\n"
                if -l $_ || !-f $_;
            push @files, $File::Find::name;
        },
    },
    $directory,
);

my (@staged, @changes);
END {
    unlink $_->[1] for grep { defined($_->[1]) && -e $_->[1] } @staged;
}

for my $file (sort @files) {
    open my $input, '<:raw', $file or die "error: cannot read $file: $!\n";
    my $contents = <$input> // '';
    close $input or die "error: cannot close $file: $!\n";

    my ($output, $count) = strip_descriptions($contents);
    next if !$count;

    my ($temporary, $temporary_path) = tempfile(
        '.strip-descriptions-XXXXXX',
        DIR    => do { my $path = $file; $path =~ s{/[^/]+\z}{}; $path },
        UNLINK => 0,
    );
    push @staged, [$file, $temporary_path];
    binmode $temporary;
    print {$temporary} $output or die "error: cannot write $temporary_path: $!\n";
    my $mode = (stat $file)[2] & 07777;
    chmod $mode, $temporary_path or die "error: cannot set mode on $temporary_path: $!\n";
    close $temporary or die "error: cannot close $temporary_path: $!\n";
    push @changes, [$file, $temporary_path, $count];
}

my $total = 0;
for my $change (@changes) {
    my ($file, $temporary_path, $count) = @$change;
    rename $temporary_path, $file or die "error: cannot replace $file: $!\n";
    $total += $count;
    print "$file: removed $count descriptions\n";
}
printf "Removed %d k8s descriptions from %d files\n", $total, scalar @changes;
