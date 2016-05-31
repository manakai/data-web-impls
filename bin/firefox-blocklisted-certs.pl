use strict;
use warnings;
use Path::Tiny;
use Web::DOM::Document;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;
my $src_path = $root_path->child ('local/firefox-blocklist.xml');

my $doc = new Web::DOM::Document;
$doc->inner_html ($src_path->slurp_utf8);

my $Data = {};

for my $item (@{$doc->query_selector_all ('certItem')}) {
  my $issuer = $item->get_attribute ('issuerName');
  for ($item->children->to_list) {
    if ($_->local_name eq 'serialNumber') {
      $Data->{issuers}->{$issuer}->{serial_numbers}->{$_->text_content} = 1;
    }
  }

  my $subj = $item->get_attribute ('subject');
  my $hash = $item->get_attribute ('pubKeyHash');
  if (defined $subj and defined $hash) {
    $Data->{subjects}->{$subj}->{public_key_hashes}->{$hash} = 1;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
