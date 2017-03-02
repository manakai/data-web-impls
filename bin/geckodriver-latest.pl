use strict;
use warnings;
use Web::DOM::Document;
use Path::Tiny;

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/geckodriver-latest.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($path->slurp_utf8);
  my $title = $doc->query_selector('title')->text_content;
  if ($title =~ m{ (v[0-9][0-9.]*)}) {
    my $version = $1;
    print $version;
  } else {
    warn "Title doesn't have version (title: $title)";
    exit 1;
  }
}

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
