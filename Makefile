.PHONY: all clean format docs deps
.DEFAULT_GOAL: all

MIX_ENV := $(MIX_ENV)
MIX_TARGET := $(MIX_TARGET)

ifeq ($(MIX_ENV),)
MIX_ENV := dev
endif

ifeq ($(MIX_TARGET),)
MIX_TARGET := host
endif

PROJECTS := farmbot_core \
						farmbot_ext \
						farmbot_os \
						farmbot_telemetry

all: help

help:
	@echo "Usage: "
	@echo "	make [target]"
	@echo "TARGETS: "
	@echo "	clean - clean all."

clean_other_branch:
	rm -rf _build deps c_src config tmp priv

clean: clean_other_branch
	@for project in $(PROJECTS) ; do \
		echo cleaning $$project ; \
		rm -rf $$project/erl_crash.dump ; \
		rm -rf $$project/.*.sqlite3* ; \
		rm -rf $$project/*.sqlite3* ; \
		rm -rf $$project/*.db ; \
		rm -rf $$project/_build ; \
		rm -rf $$project/deps ; \
		rm -rf $$project/priv/*.so ; \
	done

format:
	mix format
	@for project in $(PROJECTS) ; do \
		echo formatting $$project ; \
		cd $$project && mix format && cd .. ; \
	done

deps:
	@for project in $(PROJECTS) ; do \
		echo Fetching deps for $$project ; \
		cd $$project && mix deps.get && cd .. ; \
	done

docs:
	@for project in $(PROJECTS) ; do \
		echo Building docs for $$project ; \
		cd $$project && mix docs && cd .. ; \
	done
