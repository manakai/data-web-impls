use strict;
use warnings;
use Web::DOM::Document;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/firefox-locales.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($path->slurp_utf8);
  for my $a ($doc->links->to_list) {
    if ($a->text_content =~ m{^([0-9a-z-]{2,3}(?:-[A-Z]{2}|))/$}) {
      $Data->{locales}->{$1} ||= {}
          unless $1 eq 'xpi';
    }
  }
}

print perl2json_bytes_for_record $Data;

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
