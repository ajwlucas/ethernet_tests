# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET ?= XR-AVB-LC-BRD

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME =

XSIM ?= 0
TEST_2A ?= 1
TEST_2B ?= 1

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = module_ethernet module_locks

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
ifeq "$(CONFIG)" "Debug"
    XCC_FLAGS = -g -O0
else
    XCC_FLAGS = -g -O3
endif

ifeq ($(TEST_2A),1)
	XCC_FLAGS += -DTEST_2A
endif

ifeq ($(TEST_2B),1)
	XCC_FLAGS += -DTEST_2B
endif

ifeq ($(TARGET),XR-AVB-LC-BRD)
    XCC_FLAGS += -DPORT_ETH_RST_N=PORT_ETH_RSTN
    XCC_FLAGS += -DPHY_ADDRESS=0
    XCC_FLAGS += -DETH_CORE_ID=1
    ifeq ($(XSIM),0)
        XCC_FLAGS += -DXSCOPE_ENABLED=1
        XCC_FLAGS += -lxscope
    else
        XCC_FLAGS += -DSIMULATION
    endif
endif

# The VERBOSE variable, if set to 1, enables verbose output from the make
# system.
VERBOSE = 0

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

