package WebService::LogicMonitor::Entity;

# ABSTRACT: Base class for a LogicMonitor host or group entity

use v5.16.3;
use Log::Any '$log';
use Moo;

has id => (is => 'ro', predicate => 1);    # int

has name => (is => 'rw', required => 1);   # str

has description => (is => 'rw', predicate => 1);    # str

has created_on => (
    is     => 'ro',
    coerce => sub {
        DateTime->from_epoch(epoch => $_[0]);
    },
);

has type => (is => 'ro');                           # enum HOST|HOSTGROUP

has [qw/alert_enable in_sdt/] => (is => 'rw');      # bool

has properties => (
    is  => 'lazy',
    isa => sub {
        unless (ref $_[0] && ref $_[0] eq 'HASH') {
            die 'properties should be specified as a hashref';
        }
    },
);

sub _build_properties {
    my ($self, $only_own) = @_;

    $only_own //= 0;

    $log->debug('Fetching properties');

    my $data;
    if (ref $self eq 'WebService::LogicMonitor::Host') {

        # XXX this seems redundant - properties is always
        # returned by get_hosts, don't need a separate step
        # perhaps useful for refreshing?
        $data =
          $self->_lm->_get_data('getHostProperties', hostId => $self->id,);
    } else {
        $data = $self->_lm->_get_data(
            'getHostGroupProperties',
            hostGroupId       => $self->id,
            onlyOwnProperties => $only_own,
        );
    }

    # TODO weed out empty strings,
    # TODO convert comma separated strings to arrays
    my %prop = map { $_->{name} => $_->{value} } @{$data};

    return \%prop;
}

sub set_sdt {
    my $self = shift;

    my $entity;
    if (ref $self eq 'WebService::LogicMonitor::Host') {
        $entity = 'Host';
    } elsif (ref $self eq 'WebService::LogicMonitor::Group') {
        $entity = 'HostGroup';
    } else {
        die 'What am I???';
    }

    return $self->_lm->set_sdt($entity => $self->id, @_);
}

1;
