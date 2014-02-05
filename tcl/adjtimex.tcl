package provide muppet 1.2.3
package require qcode
namespace eval muppet {}

proc muppet::adjtimex_install {} {
    # Run adjtimexconfig when adjtimex is installed or upgraded?
    package_option adjtimex adjtimex/compare_rtc boolean true
    # Should adjtimex be run at installation and at every startup?
    package_option adjtimex adjtimex/run_daemon boolean false
    install adjtimex
}
