all: build data-url-samples

clean: build-clean

WGET = wget
CURL = curl
GIT = git
PERL = ./perl

updatenightly: clean local/bin/pmbp.pl deps all
	$(GIT) add data
	$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove

## ------ Build ------

SAVE = $(WGET) -O

build: data

data: data/firefox-versions.json data/firefox-locales.json \
    data/firefox-latest.txt data/firefox-blocklisted-certs.json

build-clean:
	rm -fr local/*.html

data/firefox-versions.json: bin/firefox-versions.pl \
    local/firefox-releases.html
	$(PERL) $< > $@
data/firefox-locales.json: bin/firefox-locales.pl \
    local/firefox-locales.html
	$(PERL) $< > $@
data/firefox-latest.txt: data/firefox-versions.json local/bin/jq
	local/bin/jq '.latest' -r data/firefox-versions.json > $@

local/firefox-releases.html:
	$(SAVE) $@ https://archive.mozilla.org/pub/firefox/releases/
local/firefox-locales.html: data/firefox-latest.txt
	$(SAVE) $@ https://archive.mozilla.org/pub/firefox/releases/`cat data/firefox-latest.txt`/linux-x86_64/
local/firefox-blocklist.xml:
	$(SAVE) $@ https://raw.githubusercontent.com/mozilla/gecko-dev/master/browser/app/blocklist.xml

local/bin/jq:
	mkdir -p local/bin
	$(WGET) -O $@ https://stedolan.github.io/jq/download/linux64/jq
	chmod u+x $@

local/psl.dat:	
	$(WGET) -O $@ https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat
local/psl.txt: local/psl.dat bin/psl.pl
	$(PERL) bin/psl.pl > $@

data/firefox-blocklisted-certs.json: bin/firefox-blocklisted-certs.pl \
    local/firefox-blocklist.xml
	$(PERL) $< > $@

data-url-samples: bin/parse-brank.pl bin/url-samples.pl local/psl.txt
	$(PERL) bin/parse-brank.pl > local/brank-urls.txt
	$(PERL) bin/url-samples.pl < local/brank-urls.txt > data/url-samples/brank/`perl -e '@time=gmtime;printf "%04d%02d",$$time[5]+1900,$$time[4]+1'`.txt

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps local/bin/jq

test-main:
	$(PROVE) t/*.t

## Per CC0 <https://creativecommons.org/publicdomain/zero/1.0/>, to
## the extent possible under law, the author of this file has waived
## all copyright and related or neighboring rights to the file.
