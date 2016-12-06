PROJECT = rabbitmq_trust_store
PROJECT_DESCRIPTION = Client X.509 certificates trust store
PROJECT_MOD = rabbit_trust_store_app

define PROJECT_ENV
[
	    {default_refresh_interval, 30}
	  ]
endef

DEPS = rabbit_common rabbit
## We need the Cowboy's test utilities
TEST_DEPS = rabbitmq_ct_helpers rabbitmq_ct_client_helpers amqp_client ct_helper
dep_ct_helper = git https://github.com/extend/ct_helper.git master

DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include rabbitmq-components.mk
include erlang.mk
