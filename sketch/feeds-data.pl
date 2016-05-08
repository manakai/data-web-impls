use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use HTTP::Response;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::HTML::Parser;

my ($list_file_name, $data_dir_name) = @ARGV;
die "Usage: $0 list-file data-dir" unless defined $data_dir_name;

my $list = path ($list_file_name)->slurp;
my $data_path = path ($data_dir_name);

sub origin_of ($) {
  if ($_[0] =~ m{^([^:/]+://[^/]+)}) {
    return $1;
  } else {
    return '';
  }
} # origin_of

sub parse_header_data ($) {
  my $path = $_[0];
  unless ($path->is_file) {
    return {status => 0};
  }

  my $res = HTTP::Response->parse ($path->slurp);
  my $response = {};
  $response->{status} = 0+($res->code || 0);
  my $ct = $res->header ('Content-Type') // '';
  if ($ct =~ m{^([^;\s]+)\s*;\s*charset="?([^"]+)"?$}) {
    $response->{mime_type} = $1;
    $response->{charset} = $2;
    $response->{charset} =~ tr/A-Z/a-z/;
  } elsif ($ct =~ m{^([^\s;]+)$}) {
    $response->{mime_type} = $1;
  } else {
    $response->{_bad_content_type} = $ct;
  }
  return $response;
} # parse_header_data

sub add_html_data ($$);
sub add_element_counts ($$$);
sub add_element_counts ($$$) {
  my ($child, $pkey, $data) = @_;
  my $name = ($child->namespace_uri // '') . ' ' . $child->local_name;
  $data->{counts}->{"$pkey$name"}++;
  my $key = "$pkey$name".'_';
  for ($child->children->to_list) {
    add_element_counts $_ => $key, $data;
  }
  for (@{$child->get_attribute_names}) {
    $data->{counts}->{"$key\@$_"}++;
  }
    my $rel = $child->get_attribute ('rel');
    my $type = $child->get_attribute ('type');
    if (defined $rel) {
      $data->{counts}->{"$key\@rel\_$rel"}++;
      $type //= '';
      $data->{counts}->{"$key\@rel\_$rel\_\@type_$type"}++;
    } elsif (defined $type) {
      $data->{counts}->{"$key\@type_$type"}++;
    }

  my $mode = $child->get_attribute ('mode');
  if (defined $mode) {
    $data->{counts}->{"$key\@mode_$mode"}++;
  }

  if ($child->local_name eq 'description') {
    my $text = $child->text_content;
    if ($text =~ /[<&]/) {
      $data->{counts}->{"$key.markup"}++;
      add_html_data $text => $data;
    }
  }

  if ($child->local_name eq 'encoded' or
      $child->local_name eq 'content') {
    add_html_data $child->text_content => $data;
  }

  if ($child->local_name eq 'link') {
    my $url = $child->get_attribute ('href') // $child->text_content;
    my $rel = $child->get_attribute ('rel') // '';
    if (length $url and not $rel eq 'hub') {
      my $origin = origin_of $url;
      if ($origin eq $data->{origin}) {
        $data->{counts}->{"$key\_originsame"}++;
      } else {
        $data->{counts}->{"$key\_origincross"}++;
      }
    }
  }

  if ($child->local_name eq 'category' and 
      ($child->namespace_uri || '') eq 'http://www.w3.org/2005/Atom') {
    my $term = $child->get_attribute ('term') // '';
    my $label = $child->get_attribute ('label');
    if (defined $label) {
      if ($label eq $term) {
        $data->{counts}->{"category_label=term"}++;
      } else {
        $data->{counts}->{"category_label!=term"}++;
      }
    } else {
      $data->{counts}->{"category_nolabel"}++;
    }

    my $scheme = $child->get_attribute ('scheme');
    if (defined $scheme) {
      $data->{counts}->{"category_scheme_$scheme"}++;
    }
  }

  if ($child->local_name eq 'category' and
      not defined $child->namespace_uri) {
    my $domain = $child->get_attribute ('domain');
    if (defined $domain) {
      $data->{counts}->{"category_domain_$domain"}++;
    }
  }

  if ($child->local_name eq 'docs' and
      not defined $child->namespace_uri) {
    my $value = $child->text_content;
    $data->{counts}->{"docs_$value"}++;
  }
} # add_element_counts

my $_doc = new Web::DOM::Document;
$_doc->manakai_is_html (1);
my $html_parser = Web::HTML::Parser->new;
$html_parser->onerror (sub { });
sub add_html_data ($$) {
  return unless $_[0] =~ /[<&]/;
  my $data = $_[1];
  my $el = $_doc->create_element ('div');
  my $node_list = $html_parser->parse_char_string_with_context
      ($_[0], $el, $_doc);
  
  my $key = 'htmlelement_';
  my @node = @$node_list;
  while (@node) {
    my $node = shift @node;
    next unless $node->node_type == 1;
    my $ln = $node->local_name;
    $data->{counts}->{$key.$ln}++;
    unshift @node, $node->children->to_list;
    for (@{$node->get_attribute_names}) {
      $data->{counts}->{$key.$ln.'@'.$_}++;
    }
  }
} # add_html_data

my $Data = {};
my $next_id = {};
my $i = 0;
for (split /[\x0D\x0A]+/, $list) {
  my $url = $_;
  next unless $url =~ m{\Ahttps?://([0-9a-z._-]+)};
  my $site = $1;
  my $id = ++$next_id->{$site};
  $i++;
  warn $i, "\n" if not ($i % 10);

  my $headers_path = $data_path->child ("$site.$id.headers");
  my $body_path = $data_path->child ("$site.$id.body");

  $Data->{$url}->{url} = $url;
  $Data->{$url}->{origin} = origin_of $url;
  $Data->{$url}->{header_data} = parse_header_data $headers_path;

  my $data = $Data->{$url};
  $Data->{counts}->{node}->[0]++;
  $Data->{counts}->{"node_status_$data->{header_data}->{status}"}->[0]++;
  if ($data->{header_data}->{status} == 200) {
    $Data->{counts}->{"node_mime_@{[$data->{header_data}->{mime_type}//'']}"}->[0]++;
    $Data->{counts}->{"node_charset_@{[$data->{header_data}->{charset}//'']}"}->[0]++;

    my @error;
    my $parser = Web::XML::Parser->new;
    $parser->onerror (sub {
      my %error = @_;
      if ($error{level} eq 'm') {
        push @error, \%error;
      }
    });
    my $doc = new Web::DOM::Document;
    $doc->manakai_set_url ($url);
    $parser->parse_byte_string ($data->{header_data}->{charset}, $body_path->slurp => $doc)
        if $body_path->is_file;

    $data->{xml_error_count} = 0+@error;
    if (@error) {
      $data->{xml_error_types} = [map { $_->{type} } @error];
    }

    my $de = $doc->document_element;
    my $doc_root;
    if (defined $de) {
      $doc_root = ($de->namespace_uri // '') . ' ' . $de->local_name;
    } else {
      $doc_root = '';
    }
    $data->{root} = $doc_root;
    $Data->{counts}->{"root_$doc_root"}->[0]++;

    my $mime = $data->{header_data}->{mime_type} // '';
    $Data->{counts}->{"mimeroot_$mime\_$doc_root"}->[0]++;

    if (defined $de and $de->local_name ne 'html') {
      my $key = 'element_'.$doc_root.'_';
      for my $child ($de->children->to_list) {
        add_element_counts $child => $key, $data;
      }
    }

    for (keys %{$data->{counts} || {}}) {
      if ($data->{counts}->{$_}) {
        $Data->{counts}->{$_}->[0]++;
      }
    }
  }
}

for my $key (keys %{$Data->{counts}}) {
  $Data->{counts}->{$key}->[1] = $Data->{counts}->{$key}->[0] / $Data->{counts}->{node}->[0];
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
