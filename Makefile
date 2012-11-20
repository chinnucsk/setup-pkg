
PKG=gprocpkg
VSN=$(shell git describe --always --long --tags)
RELPKG=$(PKG)-$(VSN)

OTPREL=$(shell erl -noshell -eval 'io:format(erlang:system_info(otp_release)), halt().')

.PHONY: all \
	compile \
	package \
	boot \
	restart \
	test \
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

test: clean compile package
	@echo "testing: $(RELPKG) ..."
	rel/$(RELPKG) -i -c rel/$(PKG).config -d rel
	(cd rel; erl \
		-smp +A 5 \
		-sasl errlog_type error \
		-boot releases/$(VSN)/install \
		-config releases/$(VSN)/install \
		-setup stop_when_done true)
	(cd rel; erl \
		-smp +A 5 \
		-sasl errlog_type all \
		-boot releases/$(VSN)/start \
		-config releases/$(VSN)/sys \
        -s erlang halt)

clean:
	@echo "cleaning: $(RELPKG) ..."
	-rm -rf rel/{$(RELPKG),erl_crash.dump,lib,releases}
	./rebar clean

# rm -rf rebar rebar.git
# . ~/.kerl/installations/r13b04/activate
# make -f rebar.mk rebar
# git commit -m "Update rebar (`./rebar -V | cut -d ' ' -f 6`)" rebar
rebar: rebar.git
	(cd $(CURDIR)/rebar.git && make clean && make && cp -f rebar ..)
	./rebar -V

rebar.git:
	rm -rf $(CURDIR)/rebar
	git clone git://github.com/rebar/rebar.git rebar.git
