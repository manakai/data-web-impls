use strict;
use warnings;
use Web::DOM::Document;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/firefox-releases.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($path->slurp_utf8);
  for my $a ($doc->links->to_list) {
    if ($a->text_content =~ m{^([0-9][0-9.a-z]*)/$}) {
      $Data->{releases}->{$1} ||= {};
    }
  }
}

{
  my @version;
  for (keys %{$Data->{releases}}) {
    if (/^([0-9.]+)$/) {
      push @version, [$_ => join '', map { chr $_ } split /\./, $_];
    }
  }
  @version = sort { $a->[1] cmp $b->[1] } @version;
  $Data->{latest} = $version[-1]->[0];
}

print perl2json_bytes_for_record $Data;

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
