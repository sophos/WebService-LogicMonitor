package WebService::LogicMonitor;

our $VERSION = '0.0';

# ABSTRACT: Interact with LogicMonitor through their web API

use v5.16.3;    # minimum for CentOS 7
use autodie;
use Carp;
use DateTime;
use Hash::Merge 'merge';
use LWP::UserAgent;
use JSON;
use List::Util 'first';
use List::MoreUtils 'zip';
use Log::Any qw/$log/;
use URI::QueryParam;
use URI;
use WebService::LogicMonitor::Account;
use WebService::LogicMonitor::EscalationChain;
use WebService::LogicMonitor::Host;
use WebService::LogicMonitor::SDT;
use Moo;

=attr C<company>, C<username>, C<password>

The CUP authentication details for your LogicMonitor account. See
L<http://help.logicmonitor.com/developers-guide/authenticating-requests/>

=cut

has [qw/password username company/] => (is => 'ro', required => 1);

has [qw/_base_url _auth_hash _ua/] => (is => 'lazy');

sub _build__base_url {
    my $self = shift;
    return URI->new(sprintf 'https://%s.logicmonitor.com/santaba/rpc',
        $self->company);
}

sub _build__auth_hash {
    my $self = shift;
    return {
        c => $self->company,
        u => $self->username,
        p => $self->password
    };
}

sub _build__ua {
    my $self = shift;
    return LWP::UserAgent->new(
        timeout => 10,
        agent   => __PACKAGE__ . "/$VERSION",
    );
}

sub _get_uri {
    my ($self, $method) = @_;

    my $uri = $self->_base_url->clone;
    $uri->path_segments($uri->path_segments, $method);
    $uri->query_form_hash($self->_auth_hash);
    $log->debug('URI: ' . $uri->path_query);
    return $uri;
}

sub _get_data {
    my ($self, $method, %params) = @_;

    my $uri = $self->_get_uri($method);

    if (%params) {
        foreach my $param (keys %params) {
            $uri->query_param_append($param, $params{$param});
        }
    }

    $log->debug('URI: ' . $uri->path_query);
    my $res = $self->_ua->get($uri);
    croak "Failed!\n" unless $res->is_success;

    my $res_decoded = decode_json $res->decoded_content;

    if ($res_decoded->{status} != 200) {
        croak(
            sprintf 'Failed to fetch data: [%s] %s',
            $res_decoded->{status},
            $res_decoded->{errmsg});
    }

    return $res_decoded->{data};
}

sub _send_data {
    my ($self, $method, $params) = @_;

    my $uri = $self->_get_uri($method);

    $params = merge $params, $self->_auth_hash;
    $uri->query_form_hash($params);

    $log->debug('URI: ' . $uri->path_query);

    my $res = $self->_ua->get($uri);
    croak "Failed!\n" unless $res->is_success;

    my $res_decoded = decode_json $res->decoded_content;

    if ($res_decoded->{status} != 200) {
        croak(
            sprintf 'Failed to send data: [%s] %s',
            $res_decoded->{status},
            $res_decoded->{errmsg});
    }

    return $res_decoded->{data};
}

=method C<get_escalation_chains>

Returns an arrayref of all available escalation chains.

L<http://help.logicmonitor.com/developers-guide/manage-escalation-chains/#get1>

=cut

sub get_escalation_chains {
    my $self = shift;

    my $data = $self->_get_data('getEscalationChains');

    my @chains;
    foreach my $chain (@$data) {
        $chain->{_lm} = $self;
        push @chains, WebService::LogicMonitor::EscalationChain->new($chain);
    }

    return \@chains;
}

=method C<get_escalation_chain_by_name(Str $name)>

Convenience wrapper aroung L</get_escalation_chains> which only returns chains
where a C<name eq $name>.

=cut

# TODO name or id
sub get_escalation_chain_by_name {
    my ($self, $name) = @_;

    my $chains = $self->get_escalation_chains;

    my $chain = first { $_->{name} eq $name } @$chains;
    return $chain;
}

=method C<get_accounts>

Retrieves a complete list of accounts as an arrayref.

L<http://help.logicmonitor.com/developers-guide/manage-user-accounts/#getAccounts>

=cut

sub get_accounts {
    my $self = shift;

    my $data = $self->_get_data('getAccounts');

    my @accounts;
    for (@$data) {
        $_->{_lm} = $self;
        push @accounts, WebService::LogicMonitor::Account->new($_);
    }

    return \@accounts;
}

=method C<get_account_by_email(Str $email)>

Convenience wrapper aroung L</get_accounts> which only returns accounts
matching $email.

=cut

sub get_account_by_email {
    my ($self, $email) = @_;

    my $accounts = $self->get_accounts;

    $log->debug("Searching for a user account with email address [$email]");

    my $account = first { $_->{email} =~ /$email/i } @$accounts;

    croak "Failed to find account with email <$email>" unless $account;

    return $account;
}

=method C<get_data>
  host    string  The display name of the host
  dataSourceInstance  string  The Unique name of the DataSource Instance
  period  string  The time period to Download Data from. Valid inputs include nhours, ndays, nweeks, nmonths, or nyears (ex. 2hours)
  dataPoint{0-n}  string  The unique name of the Datapoint
  start, end  long    Epoch Time in seconds
  graphId integer (Optional) The Unique ID of the Datasource Instance Graph
  graph   string  (Optional) The Unique Graph Name
  aggregate   string  (Optional- defaults to null) Take the "AVERAGE", "MAX", "MIN", or "LAST" of your data
  overviewGraph   string  The name of the Overview Graph to get data from
=cut

sub get_data {
    my ($self, %args) = @_;

    croak "'host' is required" unless $args{host};
    croak "'dsi' is required"  unless $args{dsi};

    my $uri = $self->_get_uri('getData');

    # required
    $uri->query_param_append('host',               $args{host});
    $uri->query_param_append('dataSourceInstance', $args{dsi});

    # optional
    $uri->query_param_append('start', $args{start}) if $args{start};
    $uri->query_param_append('end',   $args{end})   if $args{end};
    $uri->query_param_append('aggregate', $args{aggregate})
      if $args{aggregate};

    # XXX period seems to do nothing if start and end are specified
    $uri->query_param_append('period', $args{period}) if $args{period};

    if ($args{datapoint}) {
        croak "'datapoint' must be an arrayref"
          unless ref $args{datapoint} eq 'ARRAY';

        for my $i (0 .. scalar @{$args{datapoint}} - 1) {
            $uri->query_param_append("dataPoint$i", $args{datapoint}->[$i]);
        }
    }

    $log->debug("Fetching uri: $uri");
    my $res = $self->_ua->get($uri);
    croak "Failed!\n" unless $res->is_success;

    my $res_decoded = decode_json $res->decoded_content;

    if ($res_decoded->{status} != 200) {
        croak(
            sprintf 'Failed to fetch data: [%s] %s',
            $res_decoded->{status},
            $res_decoded->{errmsg});
    }

    my $datapoints = $res_decoded->{data}->{dataPoints};

    $log->debug('Got '
          . scalar @{$res_decoded->{data}->{values}->{$args{dsi}}}
          . ' values');
    my $tzoffset = $res_decoded->{data}->{tzoffset};    # don't need this...?

    my $data = [];
    foreach my $dsi_values (@{$res_decoded->{data}->{values}->{$args{dsi}}}) {

        # the dsi_values array provides the values for the datapoints but the first
        # two entries are time info
        my $epoch      = shift @$dsi_values;
        my $timestring = shift @$dsi_values;

        #require DateTime;
        #my $dt = DateTime->from_epoch(epoch => $epoch);

        if (scalar @$datapoints != scalar @$dsi_values) {

            # TODO just ignore this point and carry on?
            croak 'Number of datapoints doesn\'t match number of values';
        }

        my %values = zip @$datapoints, @$dsi_values;
        push @$data,
          {epoch => $epoch, timestr => $timestring, values => \%values};
    }

    return $data;
}

=method C<get_alerts(...)>

Returns an arrayref of alerts or undef if none found.

See L<http://help.logicmonitor.com/developers-guide/manage-alerts/> for
what parameters are available to filter the alerts.

=cut

sub get_alerts {
    my $self = shift;

    my $data = $self->_get_data('getAlerts', @_);

    return $data->{total} == 0
      ? undef
      : $data->{alerts};
}

=method C<get_host(Str displayname)>

Return a host.

L<http://help.logicmonitor.com/developers-guide/manage-hosts/#get1>

=cut

sub get_host {
    my ($self, $displayname) = @_;

    croak "Missing displayname" unless $displayname;

    my $data = $self->_get_data('getHost', displayName => $displayname);
    $data->{_lm} = $self;
    return WebService::LogicMonitor::Host->new($data);
}

=method C<get_hosts(Int hostgroupid)>

Return an array of hosts in the group specified by C<group_id>

L<http://help.logicmonitor.com/developers-guide/manage-hosts/#get1>

In scalar context, will return an arrayref of hosts in the group.

In array context, will return the same arrayref plus a hashref of the group.

=cut

sub get_hosts {
    my ($self, $hostgroupid) = @_;

    croak "Missing hostgroupid" unless $hostgroupid;

    my $data = $self->_get_data('getHosts', hostGroupId => $hostgroupid);

    my @hosts;
    for (@{$data->{hosts}}) {
        $_->{_lm} = $self;
        push @hosts, WebService::LogicMonitor::Host->new($_);
    }

    return wantarray
      ? (\@hosts, $data->{hostgroup})
      : \@hosts;
}

=method C<get_all_hosts>

Convenience wrapper around L</get_hosts> which returns all hosts. B<BEWARE> This will
probably take a while.

=cut

sub get_all_hosts {
    return $_[0]->get_hosts(1);
}

=method C<get_host_groups(Str|Regexp filter?)>

Returns an arrayref of all host groups.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#list>

Optionally takes a string or regexp as an argument. Only those hostgroups with names
matching the argument will be returned, or undef if there are none. If the arg is a string,
it must be an exact match with C<eq>.

=cut

sub get_host_groups {
    my ($self, $key, $name) = @_;

    my $hosts = $self->_get_data('getHostGroups');

    if (!defined $name) {
        return $hosts;
    }

    $log->debug("Filtering hosts by name: [$name]");
    $log->debug('Number of hosts found: ' . scalar @$hosts);
    my @matching_hosts;

    if (ref $name eq 'Regexp') {
        $log->debug('Filter is a regexp');
        @matching_hosts = grep { $_->{$key} =~ $name } @$hosts;
    } else {
        $log->debug('Filter is a string');
        @matching_hosts = grep { $_->{$key} eq $name } @$hosts;
    }

    $log->debug('Number of hosts after filter: ' . scalar @matching_hosts);

    return @matching_hosts ? \@matching_hosts : undef;
}

=method C<get_host_group(Int hostgroupid, Bool inherited=0)>

Returns an hashref of a host group.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#details>

While LoMo will return C<properties> as an arrayref of hashes like:

  [ { name => 'something', value => 'blah'}, ]

this method will convert to a hashref:

 { something => 'blah'}

=cut

sub get_host_group {
    my ($self, $hostgroupid, $inherited) = @_;

    croak "Missing hostgroupid" unless $hostgroupid;
    $inherited = 0 unless defined $inherited;

    my $data = $self->_get_data(
        'getHostGroup',
        hostGroupId       => $hostgroupid,
        onlyOwnProperties => $inherited
    );

    my $props = delete $data->{properties};
    foreach my $prop (@{$props}) {
        $data->{properties}->{$prop->{name}} = $prop->{value};
    }

    return $data;
}

=method C<get_host_group_children(Int hostgroupid)>

Gets the children host groups of C<$hostgroupid>.

In scalar context, will return an arrayref of child groups.

In array context, will return the same arrayref plus a hashref of the parent group.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#children>

=cut

sub get_host_group_children {
    my ($self, $hostgroupid) = @_;

    croak "Missing hostgroupid" unless $hostgroupid;

    my $data =
      $self->_get_data('getHostGroupChildren', hostGroupId => $hostgroupid);

    return wantarray
      ? ($data->{items}, $data->{group})
      : $data->{items};
}

=method C<update_host_group(Int hostgroupid)>

Update host group C<$hostgroupid>.

L<http://help.logicmonitor.com/developers-guide/manage-host-group/#update>

According to LoMo docs, this should return the updated hostgroup in the
same format as C<getHostGroup>, but there are different keys and properties is missing.

Even if you are only wanting to add a property, anything not set will be reset.
=cut

sub update_host_group {
    my ($self, $hostgroupid, %args) = @_;

    # TODO improve this by passing a group hashref instead of $hostgroup id
    # and copying over any relevant keys

    # TODO make convenience wrapper different opType, e,g add_property_to_host_group
    croak "Missing hostgroupid" unless $hostgroupid;
    croak "Missing name" unless $args{name};

    # first, get the required params
    my $params = {
        id   => $hostgroupid,
        name => delete $args{name},
    };

    # then get properties because they need to be formatted
    my $properties = delete $args{properties};

    if ($properties) {
        if (ref $properties ne 'HASH') {
            croak 'properties should be specified as a hashref';
        }

        my $i = 0;
        while (my ($k, $v) = each %$properties) {
            $params->{"propName$i"}  = $k;
            $params->{"propValue$i"} = $v;
            $i++;
        }
    }

    # get the rest of the args
    $params = merge $params, \%args;
    return $self->_send_data('updateHostGroup', $params);
}

=method C<get_sdts(Str key?, Int id?)>

Returns an array of SDT hashes. With no args, it will return all SDTs in the
account. See the LoMo docs for details on what keys are supported.

L<http://help.logicmonitor.com/developers-guide/schedule-down-time/get-sdt-data/>

=cut

sub get_sdts {
    my ($self, $key, $id) = @_;

    my $data;
    if ($key) {
        defined $id or croak 'Can not specify a key without an id';
        $data = $self->_get_data('getSDTs', $key => $id);
    } else {
        $data = $self->_get_data('getSDTs');
    }

    my @sdts;
    for (@$data) {
        $_->{_lm} = $self;
        push @sdts, WebService::LogicMonitor::SDT->new($_);
    }

    return \@sdts;
}

=method C<set_sdt(Str entity, Int|Str id, Int type, DateTime|Hashref start, DateTime|Hashref end, Str comment?)>

Sets SDT for an entity. Entity can be

  Host
  HostGroup
  HostDataSource
  DataSourceInstance
  HostDataSourceInstanceGroup
  Agent

The id for Host can be either an id number or hostname string.

To simplify calling this we take two keys, C<start> and C<end> which must
be DateTime objects.

L<http://help.logicmonitor.com/developers-guide/schedule-down-time/set-sdt-data/>

=cut

sub set_sdt {
    my ($self, $entity, $id, %args) = @_;

    # generate the method name and id key from entity
    my $method = 'set' . $entity . 'SDT';
    my $id_key;

    if ($id =~ /^\d+$/) {
        $id_key = lcfirst $entity . 'Id';
    } elsif ($entity eq 'Host') {
        $id_key = 'host';
    } else {
        croak "Invalid parameters - $entity => $id";
    }

    if (exists $args{type} && $args{type} != 1) {
        croak 'We only handle one-time SDTs right now';
    }

    my $params = {
        $id_key => $id,
        type    => $args{type},
    };

    $params->{comment} = $args{comment} if exists $args{comment};

    croak 'Missing start time' unless $args{start};
    croak 'Missing end time'   unless $args{end};

    # LoMo expects months to be 0..11
    if (ref $args{start} eq 'DateTime') {
        my $dt = $args{start};

        @$params{(qw/year month day hour minute/)} =
          ($dt->year, ($dt->month - 1), $dt->day, $dt->hour, $dt->minute);
    }

    if (ref $args{end} eq 'DateTime') {
        my $dt = $args{end};

        @$params{(qw/endYear endMonth endDay endHour endMinute/)} =
          ($dt->year, ($dt->month - 1), $dt->day, $dt->hour, $dt->minute);
    }

    my $res = $self->_send_data($method, $params);
    $res->{_lm} = $self;
    return WebService::LogicMonitor::SDT->new($res);
}

=method C<set_quick_sdt(Str entity, Int|Str id, $hours, ...)>

Wrapper around L</set_sdt> to quickly set SDT of a specified number of hours.

=cut

sub set_quick_sdt {
    my $self   = shift;
    my $entity = shift;
    my $id     = shift;
    my $hours  = shift;

    my $start_dt = DateTime->now(time_zone => 'UTC');
    my $end_dt = $start_dt->clone->add(hours => $hours);

    return $self->set_sdt(
        $entity, $id,
        start => $start_dt,
        end   => $end_dt,
        @_
    );
}

1;

__END__

=head1 SYNOPSIS

  use v5.14.1;
  use strict;
  use Try::Tiny;
  use WebService::LogicMonitor;

  # find a hostgroup by name, iterate through its child groups
  # and check the status of a datasource instance

  my $lm = WebService::LogicMonitor->new(
      username => $ENV{LOGICMONITOR_USER},
      password => $ENV{LOGICMONITOR_PASS},
      company  => $ENV{LOGICMONITOR_COMPANY},
  );

  my $datasource = 'Ping';
  my $host_groups  = try {
      my $hg = $lm->get_host_groups(name => 'Abingdon');
      die 'No such host group' unless $hg;
      $lm->get_host_group_children($hg->[0]{id});
  } catch {
      die "Error retrieving host group: $_";
  };

  die 'Host group has no children' unless $host_groups;

  foreach my $hg (@$host_groups) {
      say "Checking group: $hg->{name}";
      my $hosts = $lm->get_hosts($hg->{id});

      foreach my $host (@$hosts) {
          say "\tChecking host: $host->{hostName}";
          my $instances = try {
              $lm->get_data_source_instances($host->{id}, $datasource);
          }
          catch {
              say "Failed to retrieve data source instances: " . $_;
              return undef;
          };

          next unless $instances;

          # only one instance
          my $instance = shift @$instances;

          say "\t\tdatasource status: " . ($instance->{enabled} ? 'enabled' : 'disabled');
          say "\t\talert status: " . ($instance->{alertEnable} ? 'enabled' : 'disabled');
          say "\t\tgroup disabled: " . ($instance->{disabledAtGroup} ? "yes: $instance->{disabledAtGroup}" : 'no');
      }
  }
