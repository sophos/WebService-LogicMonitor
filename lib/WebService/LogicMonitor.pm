package WebService::LogicMonitor;

use v5.14.2;
use Moo;
use autodie;
use Carp;
use Hash::Merge 'merge';
use LWP::UserAgent;
use JSON;
use List::Util qw/first/;
use Log::Any qw/$log/;
use URI::QueryParam;
use URI;

has lm_password => (is => 'ro', required => 1);
has lm_username => (is => 'ro', required => 1);
has lm_company  => (is => 'ro', default  => 'sophos');

has [qw/_lm_base_url _lm_auth_hash _ua/] => (is => 'lazy');

sub _build__lm_base_url {
    my $self = shift;
    return URI->new(sprintf 'https://%s.logicmonitor.com/santaba/rpc',
        $self->lm_company);
}

sub _build__lm_auth_hash {
    my $self = shift;
    return {
        c => $self->lm_company,
        u => $self->lm_username,
        p => $self->lm_password
    };
}

sub _build__ua {
    my $self = shift;
    return LWP::UserAgent->new(timeout => 10);
}

sub _get_uri {
    my ($self, $method) = @_;

    my $uri = $self->_lm_base_url->clone;
    $uri->path_segments($uri->path_segments, $method);
    $uri->query_form_hash($self->_lm_auth_hash);
    $log->debug('URI: ' . $uri->path_query);
    return $uri;
}

sub _get_data {
    my ($self, $method) = @_;

    my $uri = $self->_get_uri($method);

    my $res = $self->_ua->get($uri);
    croak "Failed!\n" unless $res->is_success;

    my $res_decoded = decode_json $res->decoded_content;

    # TODO check status/error codes from API
    my $data = $res_decoded->{data};
    return $data;
}

sub _send_data {
    my ($self, $uri) = @_;
    my $res = $self->_ua->get($uri);
    croak "Failed!\n" unless $res->is_success;
    my $res_decoded = decode_json $res->decoded_content;
    return;
}

sub get_escalation_chains {
    my $self = shift;

    return $self->_get_data('getEscalationChains');
}

# TODO name or id
sub get_escalation_chain_by_name {
    my ($self, $name) = @_;

    my $chains = $self->get_escalation_chains;

    my $chain = first { $_->{name} eq $name } @$chains;
    return $chain;
}

=method C<update_escalation_chain(HashRef $chain)>

id and name are the minimum to update a chain, but everything else that is
not sent in the update will be reset to defaults.

=cut

sub update_escalation_chain {
    my ($self, $chain) = @_;

    my $uri = $self->_get_uri('updateEscalatingChain');

    my $params = merge $chain, $self->_lm_auth_hash;

    if ($params->{destination}) {
        $params->{destination} = encode_json $params->{destination};
    }

    $uri->query_form_hash($params);

    $log->debug('URI: ' . $uri->path_query);

    return $self->_send_data($uri);
}

sub get_accounts {
    my $self = shift;

    return $self->_get_data('getAccounts');
}

sub get_account_by_email {
    my ($self, $email) = @_;

    my $accounts = $self->get_accounts;

    my $account = first { $_->{email} =~ /$email/i } @$accounts;

    croak "Failed to find account with email <$email>" unless $account;

    return $account;
}

1;
