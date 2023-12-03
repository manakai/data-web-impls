use strict;
use warnings;
use Path::Tiny;

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/geckodriver-latest.html');
  if ($path->slurp_utf8 =~ m{/mozilla/geckodriver/releases/tag/(v[0-9][0-9.]*)}) {
    my $version = $1;
    print $version;
  } else {
    warn "Version tag not found in |$path|";
    exit 1;
  }
}

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
