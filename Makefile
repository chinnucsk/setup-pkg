
PKG=gprocpkg
VSN=$(shell git describe --always --tags)
RELPKG=$(PKG)-$(VSN)

OTPREL=$(shell erl -noshell -eval 'io:format(erlang:system_info(otp_release)), halt().')

.PHONY: all \
	compile \
	package \
	boot \
	restart \
	clean

all: compile

compile:
	@echo "compiling: $(RELPKG) ..."
	./rebar compile
	find deps -wholename "*/ebin/*.hrl" -exec rm {} \;
	find deps -wholename "*/ebin/.gitignore" -exec rm {} \;

package:
	@echo "package: $(RELPKG) ..."
	-rm -rf rel/{$(RELPKG),erl_crash.dump,lib,releases}
	erlc -DVSN=\"$(VSN)\" -DPKG=\"$(PKG)\" -o ebin src/setup_pkg.erl
	./rebar skip_deps=true escriptize
	mv rel/setup_pkg rel/$(RELPKG)

boot: package
	@echo "booting: $(RELPKG) ..."
	rel/$(RELPKG) -i -c rel/$(PKG).config -d rel
	(cd rel; erl \
		-smp +A 5 \
		-sasl errlog_type error \
		-boot releases/$(VSN)/install \
		-config releases/$(VSN)/install \
		-setup stop_when_done true)
	(cd rel; rlwrap -adummy erl \
		-smp +A 5 \
		-sasl errlog_type all \
		-boot releases/$(VSN)/start \
		-config releases/$(VSN)/sys)

restart:
	@echo "restarting: $(RELPKG) ..."
	(cd rel; rlwrap -adummy erl \
		-smp +A 5 \
		-sasl errlog_type all \
		-boot releases/$(VSN)/start \
		-config releases/$(VSN)/sys)

clean:
	@echo "cleaning: $(RELPKG) ..."
	-rm -rf rel/{$(RELPKG),erl_crash.dump,lib,releases}
	./rebar clean
