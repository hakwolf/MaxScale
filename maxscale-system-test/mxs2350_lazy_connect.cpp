/**
 * MXS-2350: On-demand connection creation
 * https://jira.mariadb.org/browse/MXS-2350
 */

#include <maxtest/testconnections.h>
#include <maxbase/string.hh>

int main(int argc, char* argv[])
{
    TestConnections test(argc, argv);
    Connection c = test.maxscales->rwsplit();

    test.expect(c.connect(), "Connection should work");
    auto output = test.maxscales->ssh_output("maxctrl list servers --tsv|cut -f 4|sort|uniq").second;
    mxb::trim(output);
    test.expect(output == "0", "Servers should have no connections: %s", output.c_str());
    c.disconnect();

    test.expect(c.connect(), "Connection should work");
    test.expect(c.query("SELECT 1"), "Read should work");
    c.disconnect();

    test.expect(c.connect(), "Connection should work");
    test.expect(c.query("SELECT @@last_insert_id"), "Write should work");
    c.disconnect();

    test.expect(c.connect(), "Connection should work");
    test.expect(c.query("SET @a = 1"), "Session command should work");
    c.disconnect();

    test.expect(c.connect(), "Connection should work");
    test.expect(c.query("BEGIN"), "BEGIN should work");
    test.expect(c.query("SELECT 1"), "Read should work");
    test.expect(c.query("COMMIT"), "COMMIT command should work");
    c.disconnect();

    return test.global_result;
}
