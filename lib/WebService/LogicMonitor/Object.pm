package WebService::LogicMonitor::Object;

use Moo::Role;

has _lm => (is => 'ro', required => 1, weak_ref => 1);

1;
