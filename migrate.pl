#!/usr/bin/perl

use strict;
use warnings;
use XML::Bare;
use DateTime::Format::Strptime;
use HTML::Entities;
use HTML::WikiConverter;

our $LJ_DATE = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S',
    locale    => 'en_GB',
    time_zone => 'Europe/London',
    );

our $IK_DATE = DateTime::Format::Strptime->new(
    pattern   => '%b %d, %Y %H:%M',
    locale    => 'en_GB',
    time_zone => 'Europe/London',
    );

our $GIT_DATE = DateTime::Format::Strptime->new(
    pattern   => '%a %b %d %H:%M %Y %z',
    locale    => 'en_GB',
    time_zone => 'Europe/London',
    );

our $EPOCH = DateTime::Format::Strptime->new(
    pattern   => '%s',
    locale    => 'en_GB',
    time_zone => 'Europe/London',
    );

our $DUMP_ROOT = '/home/richard/blog/ironchicken';
our $POSTS_ROOT = '/home/richard/www-src/blog.rjlewis.me.uk/posts';

our $WC = new HTML::WikiConverter(dialect => 'Markdown');

sub post_paths {
    my @paths = sort { ($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0] } glob qq|"${DUMP_ROOT}/L-*"|;
    return @paths;
}

sub parse_post {
    my ($path) = @_;

    my $ob = new XML::Bare( file => $path );
    $ob->parse();
}

sub post_fn {
    my ($post) = @_;

    my $fn = $post->{event}->{subject}->{value} =~ s/[[:punct:]]//gr;
    $fn = $fn =~ s/\s/_/gr;
}

sub make_post_mdwn {
    my ($post) = @_;

    my $fn = post_fn $post;
    my $date = $LJ_DATE->parse_datetime($post->{event}->{eventtime}->{value});

    open(my $mdwn, ">", "$POSTS_ROOT/$fn.mdwn") or die("Could not create $POSTS_ROOT/$fn.mdwn\n");

    print $mdwn qq|[[!meta title="| . $post->{event}->{subject}->{value} =~ s/"/'/rg . qq|"]]\n|;
    print $mdwn qq|[[!meta date="| . $IK_DATE->format_datetime($date) . qq|"]]\n\n|;
    print $mdwn $WC->html2wiki('<p>' . decode_entities($post->{event}->{event}->{value} =~ s/\R/<\/p>\n<p>/rg) . '</p>');

    close $mdwn;

    my $atime = my $mtime = $EPOCH->format_datetime($date);
    utime $atime, $mtime, "$POSTS_ROOT/$fn.mdwn";
}

sub commit_post {
    my ($post) = @_;

    my $fn = post_fn $post;
    my $date = $LJ_DATE->parse_datetime($post->{event}->{eventtime}->{value});

    my $commit_msg = 'Post: ' . $post->{event}->{subject}->{value} =~ s/"/'/rg;
    my $commit_date = $GIT_DATE->format_datetime($date);

    print qq|git add $POSTS_ROOT/$fn.mdwn\n|;
    print qq|git commit -m "$commit_msg"\n|;
    print qq|GIT_COMMITTER_DATE="$commit_date" git commit --amend --date "$commit_date" -m "$commit_msg"\n|;
}

sub main {
    foreach my $path (post_paths) {
	my $post = parse_post($path);
	make_post_mdwn $post;
	commit_post $post;
    }
}

main;
