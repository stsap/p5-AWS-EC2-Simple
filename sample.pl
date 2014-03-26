#!/usr/bin/perl --

use strict;
use warnings;
use lib qw(./lib);
use AWS::EC2::Simple;

my $aws = AWS::EC2::Simple->new(
    AccessKey => "YOUR AWS ACCESS KEY",
    SecretAccessKey => "YOUR AWS SECRET ACCESS KEY",
    Region => "ap-northeast-1",
    Action => "DescribeRegions",
    IsSSL => "1",
    ReturnType => "json"
);

my $data;
if ($data = $aws->post()) {
    warn $data;
}

$aws->setAction("DescribeAddresses");
$aws->setRegion("eu-west-1");
if ($data = $aws->post()) {
    warn $data;
}

$aws->setReturnType("perl");
if ($data = $aws->post()) {
    use Data::Dumper;
    warn Dumper($data);
}
