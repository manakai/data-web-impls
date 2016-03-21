use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use HTTP::Response;
use Web::DOM::Document;
use Web::HTML::Parser;

my ($list_file_name, $data_dir_name) = @ARGV;
die "Usage: $0 list-file data-dir" unless defined $data_dir_name;

my $list = path ($list_file_name)->slurp;
my $data_path = path ($data_dir_name);

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

my $Data = {};

my $i = 0;
for (split /[\x0D\x0A]+/, $list) {
  my ($site, $url) = split / /, $_;
  next unless $site =~ /\A[0-9a-z._-]+\z/;
  warn $i++, "\n";
  $Data->{sites}->{$site}->{page}->{url} = $url;
  $Data->{sites}->{$site}->{page}->{header_data} = parse_header_data $data_path->child ("$site.page.headers");

  $url =~ m{^([^:/]+://[^/]+/)} or die "Bad input URL <$url>";
  unless ($url eq $1) {
    $Data->{sites}->{$site}->{top}->{url} = $1;
    $Data->{sites}->{$site}->{top}->{header_data} = parse_header_data $data_path->child ("$site.top.headers");
  } else {
    $Data->{sites}->{$site}->{top} = delete $Data->{sites}->{$site}->{page};
  }

  $Data->{counts}->{site}->[0]++;
  for my $key (qw(page top)) {
    my $data = $Data->{sites}->{$site}->{$key} or next;
    $Data->{counts}->{node}->[0]++;
    $Data->{counts}->{"node_status_$data->{header_data}->{status}"}->[0]++;
    $Data->{counts}->{"node_mime_@{[$data->{header_data}->{mime_type}//'']}"}->[0]++;
    $Data->{counts}->{"node_charset_@{[$data->{header_data}->{charset}//'']}"}->[0]++;

    if ($data->{header_data}->{status} == 200 and
        ($data->{header_data}->{mime_type} || '') eq 'text/html') {
      my $path = $data_path->child ("$site.$key.body");
      my $parser = Web::HTML::Parser->new;
      $parser->onerror (sub { });
      my $doc = new Web::DOM::Document;
      $doc->manakai_is_html (1);
      $doc->manakai_set_url ($data->{url});
      $parser->parse_byte_string ($data->{header_data}->{charset}, $path->slurp => $doc)
          if $path->is_file;
      for my $el ($doc->query_selector_all (q{
        link[rel~=alternate],
        a[rel~=alternate],
        area[rel~=alternate],
        link[rel~=ALTERNATE],
        a[rel~=ALTERNATE],
        area[rel~=ALTERNATE],
        link[rel~=Alternate],
        a[rel~=Alternate],
        area[rel~=Alternate],
        link[rel~=feed], a[rel~=feed], area[rel~=feed],
        link[rel~=FEED], a[rel~=FEED], area[rel~=FEED],
        link[rel~=Feed], a[rel~=Feed], area[rel~=Feed]
      })->to_list) {
        my $link = {
          local_name => $el->local_name,
          rels => {map { $_ => 1 } @{$el->rel_list}},
          href => $el->href,
          type => $el->get_attribute ('type') // '',
          hreflang => $el->get_attribute ('hreflang') // '',
          media => $el->get_attribute ('media') // '',
          title => $el->title,
        };
        for (keys %{$link->{rels}}) {
          $Data->{counts}->{"link_rel_$_"}->[0]++;
        }
        #$Data->{counts}->{"link_type_$link->{type}"}->[0]++;
        #$Data->{counts}->{"link_media_$link->{media}"}->[0]++;
        #$Data->{counts}->{"link_localname_$link->{local_name}"}->[0]++;
        push @{$data->{alternates} ||= []}, $link;
        if ($link->{rels}->{feed} or
            (lc $link->{type}) eq 'application/atom+xml' or
            (lc $link->{type}) eq 'application/rss+xml') {
          $link->{is_feed} = 1;
          $Data->{counts}->{"feedlink_type_$link->{type}"}->[0]++;
          $Data->{counts}->{"feedlink_media_$link->{media}"}->[0]++;
          $Data->{counts}->{"feedlink_localname_$link->{local_name}"}->[0]++;
          $Data->{sites}->{$site}->{$key}->{has_feed_link} = 1;
        }
      }

      #$Data->{counts}->{"node_altlink_@{[0+@{$data->{alternates} || []}]}"}->[0]++;
      my $feed_links = [grep { $_->{is_feed} } @{$data->{alternates} || []}];
      $Data->{counts}->{"node_feedlink_@{[0+@$feed_links]}"}->[0]++;
      $Data->{counts}->{node_feedlink}->[0]++ if @$feed_links;
      $data->{feed_link_count} = @$feed_links;
    }
  }
  if (not defined $Data->{sites}->{$site}->{page}) {
    if ($Data->{sites}->{$site}->{top}->{has_feed_link}) {
      $Data->{counts}->{page_feedlink}->[0]++;
      $Data->{counts}->{pageortop_feedlink}->[0]++;
    }
  } else {
    if ($Data->{sites}->{$site}->{page}->{has_feed_link}) {
      $Data->{counts}->{page_feedlink}->[0]++;
      $Data->{counts}->{pageortop_feedlink}->[0]++;
    } elsif ($Data->{sites}->{$site}->{top}->{has_feed_link}) {
      $Data->{counts}->{pageortop_feedlink}->[0]++;
    }
  }
}

for my $key (keys %{$Data->{counts}}) {
  $Data->{counts}->{$key}->[1] = $Data->{counts}->{$key}->[0] / $Data->{counts}->{node}->[0];
  $Data->{counts}->{$key}->[2] = $Data->{counts}->{$key}->[0] / $Data->{counts}->{site}->[0];
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
