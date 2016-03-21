use strict;
use warnings;
use Path::Tiny;

my ($list_file_name, $dest_dir_name) = @ARGV;
die "Usage: $0 list-file dest-dir" unless defined $dest_dir_name;

my $list = path ($list_file_name)->slurp;
my $dest_path = path ($dest_dir_name);
$dest_path->mkpath;

for (split /[\x0D\x0A]+/, $list) {
  my ($site, $url) = split / /, $_;
  next unless $site =~ /\A[0-9a-z._-]+\z/;

  my $headers_path = $dest_path->child ("$site.page.headers");
  my $body_path = $dest_path->child ("$site.page.body");
  
  system 'curl',
      '-o', $body_path,
      '--dump-header', $headers_path,
      $url;

  $url =~ m{^([^:/]+://[^/]+/)} or die "Bad input URL <$url>";
  my $top_url = $1;
  my $top_headers_path = $dest_path->child ("$site.top.headers");
  my $top_body_path = $dest_path->child ("$site.top.body");

  system 'curl',
      '-o', $top_body_path,
      '--dump-header', $top_headers_path,
      $top_url;
}

## License: Public Domain.
