package AWS::EC2::Simple;

use strict;
use warnings;
use Digest::SHA qw(hmac_sha256);
use LWP::UserAgent;
use MIME::Base64 qw(encode_base64 decode_base64);
use POSIX qw(strftime);
use URI;
use URI::Escape qw(uri_escape_utf8);
use JSON;
use XML::Simple;

use constant REGIONS => qw(eu-west-1 sa-east-1 us-east-1 ap-northeast-1 us-west-2 us-west-1 ap-southeast-1 ap-southeast-2);

sub new {
    my $class = shift;
    my %params = (
        "AccessKey" => "",
        "SecretAccessKey" => "",
        # default is ap-northeast-1
        "Region" => "",
        # deprecated
        "Service" => "",
        # 0 / 1
        "IsSSL" => "",
        # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/query-apis.html
        "Action" => "",
        # PERL | JSON | RAW(xml)
        "ReturnType" => "",
        @_
    );
    my $self = bless(\%params, $class);
    $self->_checkValidInitialParameters();
    $self->_setProperties();
    return $self;
}

## @cmethod setReturnType
# Specifies the format of the value that is returned by the execution of the "post" method
# @param type [$] XML or RAW|JSON|PERL
sub setReturnType {
    my $self = shift;
    die("unknown return type: ".$_[0]) if ($_[0] !~ /^(?:xml|json|raw|perl)$/msxi);
    $self->{"ReturnType"} = $_[0];
}

## @cmethod setAction
# set the EC2 API Action
# @param action [$] action name
# @see http://docs.aws.amazon.com/AWSEC2/latest/APIReference/query-apis.html
sub setAction {
    my $self = shift;
    $self->{"Action"} = shift;
}

## @cmethod setRegion
# set the target AWS region
# @param region [$] definited AWS Region name
sub setRegion {
    my $self = shift;
    die("unknown region: ".$_[0]) if (not grep({ $_ eq $_[0]} (REGIONS)));
    $self->{"Region"} => $_[0];
}

## @cmethod post
# call the specified AWS API
# @return [$] 
sub post {
    my $self = shift;
    $self->{"Timestamp"} = $self->_timestamp();
    my %params = $self->_rehashRequestParams();
    $params{"Signature"} = $self->_createSignedParam(%params);
    my $ua = LWP::UserAgent->new();
    my $host = URI->new($self->_createURI({withScheme => 1}));
    $host->query_form(\%params);
    my $res = $ua->get($host->as_string);
    return undef if (not $res->is_success);
    if ($self->{"ReturnType"} =~ /^PERL$/msxi) {
        return XML::Simple::XMLin($res->content);
    } elsif ($self->{"ReturnType"} =~ /^JSON$/msxi) {
        return JSON::encode_json(XML::Simple::XMLin($res->content));
    } elsif ($self->{"ReturnType"} =~ /^RAW|XML$/msxi) {
        return $res->content;
    } else {
        die("unknown return type: ".$self->{"ReturnType"});
    }
}

## @fn _timestamp
# Generate time string that represents the current
# @return [$] time string
sub _timestamp {
    return strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
}

## @fn _createURI
# generates a request URL to AWS
# @param param [$] parameters hashref
# - withScheme [$] 0 => return only hostname | 1 => return URI with http:// or https:// scheme
# @return [$] aws api uri
sub _createURI {
    my $self = shift;
    my $param = shift;
    my $uri = URI->new($self->{"Scheme"}.join(".", $self->{"Region"}, $self->{"Service"}, $self->{"baseUrl"}));
    return ($param->{"withScheme"}) ? $uri->as_string: $uri->host;
}

## @fn _createSignedParam
# Generate AWS signature
# @param params [%] request parameters hash
# - AccessKey
# - Action
# - SignatureMethod
# - SignatureVersion
# - Timestamp
# - Version
# @return [$] hashed signature string
sub _createSignedParam {
    my $self = shift;
    my %params = @_;
    my $query = join("&", map({ $_."=".uri_escape_utf8($params{$_}) } sort(keys(%params))));
    my $signing = sprintf("GET\n%s\n/\n%s", $self->_createURI({withScheme => 0}), $query);
    return encode_base64(hmac_sha256($signing, $self->{"SecretAccessKey"}), "");
}

## @fn _rehashRequestParams
# rehash values for the HTTP request
# @return [%] rehashed parameters
sub _rehashRequestParams {
    my $self = shift;
    my %params;
    foreach ("AccessKey", "Action", "SignatureMethod", "SignatureVersion", "Timestamp", "Version") {
        my $key = ($_ eq "AccessKey") ? "AWSAccessKeyId": $_;
        $params{$key} = $self->{$_};
    }
    return %params;
}

## @fn _checkValidInitialParameters
# check AccessKey and SecretAccessKey includes in the initial parameter
sub _checkValidInitialParameters {
    my $self = shift;
    die("AccessKey is required.") if (not $self->{"AccessKey"});
    die("SecretAccessKey is required.") if (not $self->{"SecretAccessKey"});
}

## @fn _setProperties
# sets class properties
sub _setProperties {
    my $self = shift;
    $self->{"baseUrl"} = "amazonaws.com";
    $self->{"Service"} = "ec2";

    my $region = ($self->{"Region"}) ? $self->{"Region"}: "ap-northeast-1";
    my $rtype = ($self->{"ReturnType"}) ? $self->{"ReturnType"}: "JSON";
    $self->setRegion(($self->{"Region"}) ? $self->{"Region"}: "ap-northeast-1");
    $self->setReturnType($rtype);

    $self->{"Scheme"} = ($self->{"IsSSL"}) ? "https://": "http://";
    $self->{"SignatureMethod"} = (not $self->{"SignatureMethod"}) ? "HmacSHA256": $self->{"SignatureMethod"};
    $self->{"SignatureVersion"} = (not $self->{"SignatureVersion"}) ? 2: $self->{"SignatureVersion"};
    $self->{"Version"} = (not $self->{"Version"}) ? "2012-07-20": $self->{"Version"};
}

1;
