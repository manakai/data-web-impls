use strict;
use warnings;
use Path::Tiny;

my ($list_file_name, $dest_dir_name) = @ARGV;
die "Usage: $0 list-file dest-dir" unless defined $dest_dir_name;

my $list = path ($list_file_name)->slurp;
my $dest_path = path ($dest_dir_name);
$dest_path->mkpath;

my $next_id = {};

for (split /[\x0D\x0A]+/, $list) {
  my $url = $_;
  next unless $url =~ m{\Ahttps?://([0-9a-z._-]+)};
  my $site = $1;
  my $id = ++$next_id->{$site};

  my $headers_path = $dest_path->child ("$site.$id.headers");
  my $body_path = $dest_path->child ("$site.$id.body");
  system 'curl',
      '-o', $body_path,
      '--dump-header', $headers_path,
      $url;
}

## License: Public Domain.
