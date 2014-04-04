
#! /usr/bin/perl
# Download voice and transcripts from abc.net.au!
# We do everything for improving out English!
# Author: Jia.Tsui@gmail.com

# Date of last effective: 2010. 9. 26
# This script is COPYING under GPL v2.
# 0.2.5 removed Date::Time requirement
# 0.2.4 added lwpdownload.pm
# 0.2.2 fix a bug. filter voice file like 20100918-sam-full-program.mp3

use HTML::Parser;
use HTML::TreeBuilder;
use File::Basename qw/ basename /;

require "lwpdownload.pm";

$VER = "0.2.5";
$archive_url = "http://www.abc.net.au/am/indexes/"; #2010/am_20100911.htm
my $p_name, my $web_dir = "web";
my $year, my $month, my $day;

if(@ARGV == 0){ # get today's media
    ($sec, $min, $hour, $day, $month, $year, @useless) = localtime time;
    $month += 1;
    $year += 1900;
    print "Hi buddy, I'm trying to get today's stories from abc.net.au...\n";
}elsif(@ARGV == 1){
    $_ = $ARGV[0];
    if(/(\d\d\d\d)(\d\d)(\d\d)/){
	$year = $1, $month = $2, $day = $3;
    }else{
	print "VERSION: $VER\n-----------------\n";
	print "Hi buddy, this is an automative download program for English learners.\n";
	print "It downloads voice media and transcripts from abc.net.au and save to \n .mp3 and .txt files for you.\n";
	print "Using is simple, just give me the date you're intrested or leave it \nblank to try to find today's stories.\n";
	print "USAGE:\n\tbin\\perl dld.pl [DATE in YYYYMMDD format] \n";
	print "\t for example:\n";
	print "\t bin\\perl dld.pl 20100910\n";
	print "Hope you can have fun in learning English.\n";
	exit 1;
    }
}

$p_name = sprintf "am_%4d%02d%02d.htm", $year, $month, $day;
$url = sprintf "%s%04d/%s", $archive_url, $year, $p_name;

mkdir $web_dir if (! -d $web_dir);
$res = lwpdownload::download($url, $web_dir . "/" . $p_name) if ( ! -f $web_dir . "/" . $p_name);
if ($res != 0){
    unlink $web_dir . "/" . $p_name;
    print "\n\nSorry buddy, abc.net.au seems forget to update today's new story to their archive section.\n";
    print "Try a specific date before today or the date of $year$month$day (in YYYYMMDD format).";
    exit;
}

my $tree_obj = HTML::TreeBuilder->new;
my $tree = $tree_obj->parse_file($web_dir . "/" . $p_name) or die $!;

@h1 = $tree->find_by_tag_name('h1') or die $!;

foreach (@h1){
    print $_->as_text, "\n";
}

print "\n";


@div_story = $tree->find_by_attribute("class", "story-teaser amextras41") or die $1;
#$div_main_cnt = @div_main_cnt;

my %plinks = (); # page link
my %mlinks = (); # media link
my %imgtexts = (); # photo texts
my %imglinks = (); # img links
my $pkg_dir = undef;

foreach (@div_story){
    my $ml, my $sn; # media link, story name
    $div = $_->look_down("class", "storyplayer") or die $!;
    foreach (@{$div->extract_links('a') or die $!}){  # look up media link;
	my($link, $ele, $attr, $tag) = @$_;
	$ml = $link;
	if(!$pkg_dir){
	    $pkg_dir = basename($ml) if !$pkg_dir;	
	    $pkg_dir =~ s/(\d{8}).*-(.*)/$1/;
	    if(! -d $pkg_dir){
		mkdir $pkg_dir;
	    }
	}
    }

    $div = $_->look_down("_tag", "h4") or die $!;
    foreach  (@{$div->extract_links('a') or die $!}){
	my($link, $ele, $attr, $tag) = @$_;
	$sn = $ele->as_text;
	$plinks{$sn} = $link;
	$mlinks{$sn} = $ml;
    }

    $div = $_->look_down("class", "images");
    if (!$div){
	next;
    }
    foreach  (@{$div->extract_links('a') or die $!}){
	my($link, $ele, $attr, $tag) = @$_;
	%ele = %$ele;
	if($imgtexts{$sn}){
	    $imgtexts{$sn} .= "**" . $ele{"title"};
	    $imglinks{$sn} .= "**" . $link;
	}else{
	    $imgtexts{$sn} = $ele{"title"};
	    $imglinks{$sn} = $link;
	}

    }
}

#my %plinks = (); # page link
#my %mlinks = (); # media link
#my %imgtexts = (); # photo texts
#my %imglinks = (); # img links

open H, ">$pkg_dir/rel.dat" or die $!; # title $@$ transcript file $@$ media name $@$ imgtexts $@$ img name
$der = '$@$'; # delimiter

foreach my $n (keys %mlinks){
    next if(!$imgtexts{$n} && $mlinks{$n} =~ m/full-program.*\.mp3$/i);
# save transcript
    $s_name = basename($mlinks{$n}); # stored name
    $s_name =~ s/\.mp3$//;
    if ( ! -f $pkg_dir . "/" . $s_name . ".htm" ){
	print "Downloading " . $s_name . ".htm ...\n";
	lwpdownload::download($plinks{$n}, $pkg_dir . "/" . $s_name . ".htm")
    }
# save media
    if ( ! -f $pkg_dir . "/" . $s_name . ".mp3" ){
	print "Downloading " . $s_name . ".mp3 ...\n\r";
	lwpdownload::download($mlinks{$n}, $pkg_dir . "/" . $s_name . ".mp3")
    }
    @urls = split(/\*\*/, $imglinks{$n});
    $counter = 0;
    foreach my $img_url (@urls){
	if ( ! -f $pkg_dir . "/" . $s_name . "_" . $counter . ".jpg" ){
	    print "Downloading " . $s_name . "_" . $counter . ".jpg ...\n\r";
	    lwpdownload::download($img_url, $pkg_dir . "/" . $s_name . "_" . $counter++ . ".jpg")
	}
    }

    print H $s_name, $der, $n, $der, $imgtexts{$n}, "\n";
}
close H;

print "\nWe made it! All files are downloaded to $year$month$day directory.\n";

exit 0;

