package WebService::LogicMonitor::Group;

# ABSTRACT: A LogicMonitor Group object

use v5.16.3;
use Log::Any '$log';
use Moo;

with 'WebService::LogicMonitor::Object';

sub BUILDARGS {
    my ($class, $args) = @_;

    my %transform = (
        createdOn   => 'created_on',
        alertEnable => 'alert_enable',
        fullPath    => 'full_path',
        parentId    => 'parent_id',
        numOfHosts  => 'num_hosts',
        inNSP       => 'in_nsp',
        inSDT       => 'in_sdt',

    );

    for my $key (keys %transform) {
        $args->{$transform{$key}} = delete $args->{$key}
          if exists $args->{$key};
    }

    for my $k (qw/description/) {
        if (exists $args->{$k} && !$args->{$k}) {
            delete $args->{$k};
        }
    }

    return $args;
}

has id => (is => 'ro', predicate => 1);    # int

has name => (is => 'rw', required => 1);   # str

has description => (is => 'rw');           # str

has created_on => (
    is     => 'ro',
    coerce => sub {
        DateTime->from_epoch(epoch => $_[0]);
    },
);

has [qw/alert_enable in_nsp in_sdt/] => (is => 'rw');    # bool

has full_path => (is => 'rw');                           # str

has parent_id => (is => 'rw');                           # int

# num_hosts is only there if getHostGroupChildren was called
has num_hosts => (is => 'ro');                           # int

=attr C<children>

An arrayref of the children of this host group.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#children>

=cut

has children => (is => 'lazy');

=attr C<properties>, <C<own_properties>

A hashref of group properties. C<properties> includes inhertited properties,
C<own_properties> does not.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#details>

While LoMo will return C<properties> as an arrayref of hashes like:

  [ { name => 'something', value => 'blah'}, ]

this method will convert to a hashref:

 { something => 'blah'}

=cut

has [qw/properties own_properties/] => (is => 'lazy');

sub _build_own_properties {
    return $_[0]->_build_properties(1);
}

sub _build_properties {
    my ($self, $only_own) = @_;

    $only_own //= 0;

    $log->debug('Fetching group properties');

    my $data = $self->_lm->_get_data(
        'getHostGroup',
        hostGroupId       => $self->id,
        onlyOwnProperties => $only_own,
    );

    # TODO weed out empty strings,
    # TODO convert comma separated strings to arrays
    my %prop = map { $_->{name} => $_->{value} } @{$data->{properties}};

    return \%prop;
}

sub _build_children {
    my $self = shift;

    my $data =
      $self->_lm->_get_data('getHostGroupChildren', hostGroupId => $self->id);

    require WebService::LogicMonitor::Host;

    my @children = map {
        $_->{_lm} = $self->{_lm};
        if ($_->{type} eq 'HOSTGROUP') {
            WebService::LogicMonitor::Group->new($_);
        } elsif ($_->{type} eq 'HOST') {
            WebService::LogicMonitor::Host->new($_);
        } else {
            ();
        }
    } @{$data->{items}};

    return \@children;
}

=method C<update)>

Commit group to LogicMonitor.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#update>

According to LoMo docs, this should return the updated hostgroup in the
same format as C<getHostGroup>, but there are different keys and properties is missing.

Even if you are only wanting to add a property, anything not set will be reset.
=cut

sub update {
    my $self = shift;

    # TODO make convenience wrapper different opType, e,g add_property_to_host_group

    if (!$self->has_id) {
        die
          'This group does not have an id - you cannot update an object that has not been created';
    }

    # first, get the basic params
    my $params = {
        id          => $self->id,
        name        => $self->name,
        opType      => 'refresh',
        parentId    => $self->parent_id,
        description => $self->description,
        alertEnable => $self->alert_enable,
    };

    # then get properties because they need to be formatted
    my $properties = $self->properties;

    if ($properties) {
        my $i = 0;
        while (my ($k, $v) = each %$properties) {
            $params->{"propName$i"}  = $k;
            $params->{"propValue$i"} = $v;
            $i++;
        }
    }

    return $self->_lm->_send_data('updateHostGroup', $params);
}

1;
