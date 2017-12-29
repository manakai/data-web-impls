use strict;
use warnings;
use Promise;
use Promised::Flow;
use Web::UserAgent::Functions qw(http_get);
use Web::DOM::Document;
use Web::HTML::Parser;

sub get ($$$) {
  my ($y, $m, $d) = @_;
  my $date = sprintf '%04d%02d%02d', $y, $m, $d;
  my $url = q<http://b.hatena.ne.jp/ranking/daily/> . $date;
  my $try_count = 1;
  my $result;
  return (promised_wait_until {
    my $p = Promise->new (sub {
      my ($ok, $ng) = @_;
      http_get
          url => $url,
          anyevent => 1,
          timeout => 600,
          cb => sub {
            my $res = $_[1];
            if ($res->code == 200) {
              $result = [$url, $res->content];
              $ok->(1);
            } else {
              $ng->("GET <$url> failed");
            }
          };
    });
    return $p->catch (sub {
      if ($try_count++ < 4) {
        warn "Error: $_[0]; retry...\n";
        return 0;
      }
      die $_[0];
    });
  })->then (sub { return $result });
} # get

sub urls ($$$) {
  return get ($_[0], $_[1], $_[2])->then (sub {
    my ($url, $bytes) = @{$_[0]};

    my $doc = new Web::DOM::Document;
    $doc->manakai_set_url ($url);
    my $parser = new Web::HTML::Parser;
    $parser->onerror (sub { });
    $parser->parse_byte_string (undef, $bytes => $doc);

    my $main = $doc->get_element_by_id ('main');
    die "#main not found" unless defined $main;
    my @url;
    for my $a_el (
      $main->query_selector_all ('.entry-list-l .entrylist-unit h3 a.entry-link[href]')->to_list
    ) {
      push @url, $a_el->href;
    }

    return \@url;
  });
} # urls

my $year = shift;
my $month = shift // 1;
my $last = [qw(0 31 28 31 30 31 30 31 31 30 31 30 31)]->[$month];
$last++ if $month == 2 and ((not ($year % 4) and ($year % 100)) or not ($year % 400));

unless (defined $year) {
  my @time = gmtime (time - 24*60*60);
  $year = $time[5]+1900;
  $month = $time[4]+1;
  $last = $time[3];
}
my $next = 1;

my @url;
my $run; $run = sub {
  warn "$year/$month/$next\n";
  return urls ($year, $month, $next)->then (sub {
    my $urls = $_[0];
    push @url, @$urls;
    $next++;
    return $run->() if $next <= $last;
  });
}; # $run
$run->()->then (sub {
  die "URL extraction failed" unless @url;
  print map { $_ . "\n" } @url;
})->to_cv->recv;

## License: Public Domain.
