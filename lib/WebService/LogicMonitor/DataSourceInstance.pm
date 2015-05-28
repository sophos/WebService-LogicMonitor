package WebService::LogicMonitor::DataSourceInstance;

# ABSTRACT: A LogicMonitor DataSource instance

use v5.16.3;
use Log::Any '$log';
use Moo;

sub BUILDARGS {
    my ($class, $args) = @_;

    my %transform = (
        alertEnable           => 'alert_enable',
        dataSourceDisplayedAs => 'datasource_displayed_as',
        dataSourceId          => 'datasource_id',
        discoveryInstanceId   => 'discovery_instance_id',
        hostDataSourceId      => 'host_datasource_id',
        hasAlert              => 'has_alert',
        hasGraph              => 'has_graph',
        hasUnConfirmedAlert   => 'has_unconfirmed_alert',
    );

    for my $key (keys %transform) {
        $args->{$transform{$key}} = delete $args->{$key}
          if exists $args->{$key};
    }

    for my $k (qw/description wildalias wildvalue wildvalue2/) {
        if (exists $args->{$k} && !$args->{$k}) {
            delete $args->{$k};
        }
    }

    return $args;
}

has id => (is => 'ro');    # int

has [qw/name datasource_displayed_as description/] => (is => 'ro');    # str

has [qw/alert_enable enabled has_alert has_graph has_unconfirmed_alert/] =>
  (is => 'ro');                                                        # bool

has [qw/datasource_id discovery_instance_id host_datasource_id/] =>
  (is => 'ro');                                                        # int

has [qw/wildalias wildvalue wildvalue2/] => (is => 'ro');              # str

1;
