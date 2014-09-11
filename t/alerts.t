use v5.10.1;
use Test::Roo;
use Test::Fatal;
use DateTime;
use lib 't/lib';

with 'LogicMonitorTests';

has host => (is => 'ro', default => 'sxld-mcafee-eu-west-1');

# example alert
# {
#     ackComment                 "",
#     acked                      false,
#     ackedBy                    "",
#     ackedOn                    0,
#     ackedOnLocal               "",
#     active                     true,
#     alertEscalationChainName   "",
#     alertRuleName              "",
#     dataPoint                  "StorageUsed",
#     dataSource                 "snmpHRDisk-",
#     dataSourceId               462,
#     dataSourceInstance         "snmpHRDisk-/var/sxld",
#     dataSourceInstanceId       359,
#     endOn                      0,
#     endOnLocal                 "",
#     host                       "sxld-mcafee-eu-west-1",
#     hostDataSourceId           745,
#     hostGroups                 [
#         [0] {
#             alertEnable   true,
#             appliesTo     "",
#             createdOn     1402440588,
#             description   "",
#             fullPath      "AWS/eu-west-1",
#             id            7,
#             name          "eu-west-1",
#             parentId      5
#         }
#     ],
#     hostId                     10,
#     id                         224370,
#     level                      "warn",
#     startOn                    1407344153,
#     startOnLocal               "2014-08-06 16:55:53 GMT",
#     thresholds                 "",
#     type                       "alert",
#     value                      "No Data"
# }

test 'get alerts' => sub {
    my $self = shift;

    my $alerts;

    like exception {
        $alerts = $self->lm->get_alerts(badparam => 'wtf')
    }, qr/^Unknown arg: badparam/, 'Invalid param';

    is exception { $alerts = $self->lm->get_alerts }, undef,
      'got all the alerts';
    isa_ok $alerts, 'ARRAY';

    is exception { $alerts = $self->lm->get_alerts(host => $self->host) },
      undef, 'got alerts for one hsot';
    isa_ok $alerts, 'ARRAY';
};

test 'get alerts last month' => sub {
    my $self = shift;

    my $cur_dt = DateTime->now;

    # I am assuming there will always be enough data for the previous month
    my $last_month_start_dt =
      $cur_dt->clone->set_day(1)->subtract(months => 1)->subtract(days => 1)
      ->set_minute(0)->set_hour(0)->set_second(0)->add(days => 1);

    my $last_month_end_dt =
      $cur_dt->clone->set_day(1)->add(months => 1)->subtract(days => 1)
      ->set_minute(0)->set_hour(0)->set_second(0)->subtract(months => 1);

    diag
      "Getting records for one month: $last_month_start_dt - $last_month_end_dt";

    my $alerts;
    is exception {
        $alerts = $self->lm->get_alerts(
            host  => $self->host,
            start => $last_month_start_dt->epoch,
            end   => $last_month_end_dt->epoch,
          )
    }, undef, 'got some alerts';
    isa_ok $alerts, 'ARRAY';

};

run_me;
done_testing;
