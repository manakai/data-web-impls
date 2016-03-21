use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $json_file_name = shift or die "Usage: $0 json-file";
my $json = json_bytes2perl path ($json_file_name)->slurp;

my $urls = {};

for my $site (keys %{$json->{sites}}) {
  for my $key (qw(top page)) {
    my $data = $json->{sites}->{$site}->{$key};
    for (grep { $_->{is_feed} } @{$data->{alternates} || []}) {
      $urls->{$_->{href}} = 1;
    }
  }
}

print $_, "\n" for sort { $a cmp $b } keys %$urls;

## License: Public Domain.
