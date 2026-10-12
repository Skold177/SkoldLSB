"""MariaDB integration regressions for auction listing persistence.

Install PyMySQL, then point AH_TEST_MYSQL_PORT at a disposable local MariaDB
server and run `python -m unittest discover -s tools/tests -v`. Optional
AH_TEST_MYSQL_USER/PASSWORD default to root/empty. No production configuration
is read. Tests create and remove their own randomly named database.

The fixed SQL is extracted directly from ProofOfPurchase. These tests reproduce
stale inventory and an ambiguous INSERT retry using the old SQL, then verify
the guarded transfer and abrupt database TCP disconnects. They do not execute
the C++ handler or reproduce a disconnect from an actual FFXI client.
"""

import concurrent.futures
import os
from pathlib import Path
import re
import socket
import threading
import unittest
import uuid

try:
    import pymysql
except ImportError:
    pymysql = None


ROOT = Path(__file__).resolve().parents[2]


class StaleInventory(Exception):
    """The persisted item or gil disagrees with the server's inventory object."""


@unittest.skipUnless(
    pymysql is not None and os.environ.get("AH_TEST_MYSQL_PORT"),
    "requires PyMySQL and AH_TEST_MYSQL_PORT for an isolated MariaDB server",
)
class AuctionListingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / "src/map/utils/auctionutils.cpp").read_text()
        listing = source.split("void auctionutils::ProofOfPurchase(", 1)[1].split(
            "auto auctionutils::PurchasingItems(", 1
        )[0]
        queries = re.findall(r'db::preparedStmt\("([^"\n]+)"', listing)
        if len(queries) != 6:
            raise AssertionError("Update this harness for changed listing SQL")
        (
            cls.lock_sql,
            cls.count_sql,
            cls.delete_sql,
            cls.update_sql,
            cls.debit_sql,
            cls.insert_sql,
        ) = [query.replace("?", "%s") for query in queries]

        # These are the pre-fix source-removal statements in Transaction's
        # applyItemUpdate: SQL success was accepted even for zero affected rows.
        cls.legacy_delete = (
            "DELETE FROM char_inventory "
            "WHERE charid = %s AND location = %s AND slot = %s"
        )
        cls.legacy_update = (
            "UPDATE char_inventory SET quantity = %s "
            "WHERE charid = %s AND location = %s AND slot = %s"
        )
        cls.config = {
            "host": "127.0.0.1",
            "port": int(os.environ["AH_TEST_MYSQL_PORT"]),
            "user": os.environ.get("AH_TEST_MYSQL_USER", "root"),
            "password": os.environ.get("AH_TEST_MYSQL_PASSWORD", ""),
            "autocommit": True,
            "connect_timeout": 3,
            "read_timeout": 10,
            "write_timeout": 10,
        }
        cls.database = "ah_listing_test_" + uuid.uuid4().hex
        cls.admin = pymysql.connect(**cls.config)
        cls.addClassCleanup(cls.admin.close)
        with cls.admin.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE `{cls.database}`")
        cls.addClassCleanup(cls.drop_database)
        cls.admin.select_db(cls.database)
        with cls.admin.cursor() as cursor:
            cursor.execute("""CREATE TABLE char_inventory (
                charid INT UNSIGNED NOT NULL, location TINYINT UNSIGNED NOT NULL,
                slot TINYINT UNSIGNED NOT NULL, itemId SMALLINT UNSIGNED NOT NULL,
                quantity INT UNSIGNED NOT NULL, bazaar INT UNSIGNED NOT NULL DEFAULT 0,
                PRIMARY KEY(charid, location, slot)) ENGINE=InnoDB""")
            cursor.execute(
                """CREATE TABLE auction_house (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                itemid SMALLINT UNSIGNED NOT NULL, stack TINYINT UNSIGNED NOT NULL,
                seller INT UNSIGNED NOT NULL, seller_name VARCHAR(15),
                date INT UNSIGNED, price INT UNSIGNED,
                sale INT UNSIGNED NOT NULL DEFAULT 0, KEY seller(seller)) ENGINE=InnoDB"""
            )

    @classmethod
    def drop_database(cls):
        with cls.admin.cursor() as cursor:
            cursor.execute(f"DROP DATABASE `{cls.database}`")

    def setUp(self):
        self.reset()

    def reset(self, quantity=1, item=100, bazaar=0, gil=1000, missing=False, listed=0):
        with self.admin.cursor() as cursor:
            cursor.execute("DELETE FROM auction_house")
            cursor.execute("DELETE FROM char_inventory")
            cursor.execute(
                "INSERT INTO char_inventory VALUES(1,0,0,65535,%s,0)", (gil,)
            )
            if not missing:
                cursor.execute(
                    "INSERT INTO char_inventory VALUES(1,0,1,%s,%s,%s)",
                    (item, quantity, bazaar),
                )
            for _ in range(listed):
                cursor.execute(self.insert_sql, (100, 0, 1, "SqlTest", 1, 500))

    def snapshot(self):
        # Reconnect for every assertion so results are independently persisted,
        # rather than observations retained on a previous database session.
        with pymysql.connect(**self.config, database=self.database) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT slot,itemId,quantity,bazaar FROM char_inventory ORDER BY slot"
                )
                inventory = cursor.fetchall()
                cursor.execute(
                    "SELECT itemid,stack,seller,price FROM auction_house ORDER BY id"
                )
                return inventory, cursor.fetchall()

    def transfer(
        self,
        quantity=1,
        listed_quantity=1,
        item=100,
        fee=10,
        old_gil=1000,
        stack=False,
        limit=0,
        interrupt=None,
        slot=1,
        barrier=None,
    ):
        """Execute the extracted statements in the C++ transaction's order."""
        connection = pymysql.connect(**self.config, database=self.database)
        try:
            if barrier:
                barrier.wait(timeout=5)
            connection.begin()
            with connection.cursor() as cursor:
                cursor.execute(self.lock_sql, (1, 0))
                if cursor.fetchone() != (65535, old_gil):
                    raise StaleInventory("gil")
                cursor.execute(self.count_sql, (1,))
                if limit and cursor.fetchone()[0] >= limit:
                    connection.commit()
                    return "limit"
                new_quantity = quantity - listed_quantity
                if new_quantity:
                    affected = cursor.execute(
                        self.update_sql, (new_quantity, 1, 0, slot, item, quantity)
                    )
                else:
                    affected = cursor.execute(
                        self.delete_sql, (1, 0, slot, item, quantity)
                    )
                if affected != 1:
                    raise StaleInventory("source")
                if interrupt == "source":
                    return self.disconnect(connection)
                if (
                    fee
                    and cursor.execute(
                        self.debit_sql, (old_gil - fee, 1, 0, 65535, old_gil)
                    )
                    != 1
                ):
                    raise StaleInventory("fee")
                if interrupt == "fee":
                    return self.disconnect(connection)
                if (
                    cursor.execute(
                        self.insert_sql, (item, int(stack), 1, "SqlTest", 1, 500)
                    )
                    != 1
                ):
                    raise StaleInventory("insert")
                if interrupt == "insert":
                    return self.disconnect(connection)
            connection.commit()
            if interrupt == "commit":
                return self.disconnect(connection)
            return "listed"
        except StaleInventory:
            connection.rollback()
            return "rejected"
        finally:
            connection.close()

    @staticmethod
    def disconnect(connection):
        # Drop the transport without COMMIT, ROLLBACK, or COM_QUIT.
        connection._sock.shutdown(socket.SHUT_RDWR)
        connection._force_close()
        return "interrupted"

    def assert_rejected_without_changes(self, **kwargs):
        before = self.snapshot()
        self.assertEqual(self.transfer(**kwargs), "rejected")
        self.assertEqual(self.snapshot(), before)

    def assert_interruption_rolls_back(self, phase, **kwargs):
        before = self.snapshot()
        self.assertEqual(self.transfer(interrupt=phase, **kwargs), "interrupted")
        self.assertEqual(self.snapshot(), before)

    def test_single_item(self):
        self.assertEqual(self.transfer(), "listed")
        self.assertEqual(self.snapshot(), (((0, 65535, 990, 0),), ((100, 0, 1, 500),)))

    def test_full_stack(self):
        self.reset(quantity=12)
        self.assertEqual(
            self.transfer(quantity=12, listed_quantity=12, stack=True), "listed"
        )
        self.assertEqual(self.snapshot(), (((0, 65535, 990, 0),), ((100, 1, 1, 500),)))

    def test_single_from_stack(self):
        self.reset(quantity=12)
        self.assertEqual(self.transfer(quantity=12), "listed")
        self.assertEqual(
            self.snapshot(),
            (((0, 65535, 990, 0), (1, 100, 11, 0)), ((100, 0, 1, 500),)),
        )

    def test_zero_fee(self):
        self.assertEqual(self.transfer(fee=0), "listed")
        self.assertEqual(self.snapshot(), (((0, 65535, 1000, 0),), ((100, 0, 1, 500),)))

    def test_missing_source(self):
        self.reset(missing=True)
        self.assert_rejected_without_changes()

    def test_mismatched_item(self):
        self.reset(item=101)
        self.assert_rejected_without_changes()

    def test_mismatched_quantity(self):
        self.reset(quantity=2)
        self.assert_rejected_without_changes()

    def test_stale_partial_stack(self):
        self.reset(quantity=11)
        self.assert_rejected_without_changes(quantity=12)

    def test_bazaar_source(self):
        self.reset(bazaar=5)
        self.assert_rejected_without_changes()

    def test_stale_gil(self):
        self.reset(gil=900)
        self.assert_rejected_without_changes()

    def test_listing_cap(self):
        self.reset(listed=7)
        before = self.snapshot()
        self.assertEqual(self.transfer(limit=7), "limit")
        self.assertEqual(self.snapshot(), before)

    def test_disconnect_after_source(self):
        self.assert_interruption_rolls_back("source")

    def test_disconnect_after_fee(self):
        self.assert_interruption_rolls_back("fee")

    def test_disconnect_after_insert(self):
        self.assert_interruption_rolls_back("insert")

    def test_disconnect_restores_partial_stack(self):
        self.reset(quantity=12)
        self.assert_interruption_rolls_back("insert", quantity=12)

    def test_disconnect_after_commit(self):
        self.assertEqual(self.transfer(interrupt="commit"), "interrupted")
        self.assertEqual(self.snapshot(), (((0, 65535, 990, 0),), ((100, 0, 1, 500),)))

    def test_committed_disconnect_retry_rejected(self):
        # A zero fee leaves gil unchanged: the source-row guard must prevent
        # a stale request from listing again after the committed disconnect.
        self.assertEqual(self.transfer(fee=0, interrupt="commit"), "interrupted")
        self.assertEqual(self.snapshot(), (((0, 65535, 1000, 0),), ((100, 0, 1, 500),)))
        self.assert_rejected_without_changes(fee=0)

    def concurrent_stale_requests(self, quantity, stack):
        self.reset(quantity=quantity)
        barrier = threading.Barrier(2)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            attempts = [
                pool.submit(
                    self.transfer,
                    quantity=quantity,
                    listed_quantity=quantity if stack else 1,
                    fee=0,
                    stack=stack,
                    barrier=barrier,
                )
                for _ in range(2)
            ]
            outcomes = sorted(future.result() for future in attempts)
        inventory, auctions = self.snapshot()
        remaining = next((row[2] for row in inventory if row[0] == 1), 0)
        self.assertEqual(outcomes, ["listed", "rejected"])
        self.assertEqual(len(auctions), 1)
        self.assertEqual(remaining, 0 if stack else quantity - 1)
        self.assertEqual(inventory[0][2], 1000)

    def test_concurrent_single(self):
        self.concurrent_stale_requests(1, False)

    def test_concurrent_full_stack(self):
        self.concurrent_stale_requests(12, True)

    def test_concurrent_partial_stack(self):
        self.concurrent_stale_requests(12, False)

    def test_concurrent_listing_cap(self):
        self.reset(listed=6)
        with self.admin.cursor() as cursor:
            cursor.execute("INSERT INTO char_inventory VALUES(1,0,2,100,1,0)")
        barrier = threading.Barrier(2)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            attempts = [
                pool.submit(self.transfer, slot=slot, fee=0, limit=7, barrier=barrier)
                for slot in (1, 2)
            ]
            outcomes = sorted(future.result() for future in attempts)
        inventory, auctions = self.snapshot()
        self.assertEqual(outcomes, ["limit", "listed"])
        self.assertEqual(len(auctions), 7)
        self.assertEqual(len(inventory), 2)

    def test_reproduces_legacy_moved_item_dupe_and_rejects_fixed(self):
        # A stale entity remembers slot 1, while the real item is in slot 2.
        with self.admin.cursor() as cursor:
            cursor.execute("UPDATE char_inventory SET slot=2 WHERE slot=1")
            self.assertEqual(cursor.execute(self.legacy_delete, (1, 0, 1)), 0)
            cursor.execute(self.insert_sql, (100, 0, 1, "SqlTest", 1, 500))
        inventory, auctions = self.snapshot()
        self.assertEqual(inventory[1], (2, 100, 1, 0))
        self.assertEqual(len(auctions), 1)  # Original still exists: duplication.
        self.reset()
        with self.admin.cursor() as cursor:
            cursor.execute("UPDATE char_inventory SET slot=2 WHERE slot=1")
        self.assert_rejected_without_changes()

    def test_reproduces_legacy_quantity_dupe_and_rejects_fixed(self):
        # Memory says 12; persisted stack has only 11. Old code writes 11 and
        # lists one without consuming any persisted item.
        self.reset(quantity=11)
        with self.admin.cursor() as cursor:
            self.assertEqual(cursor.execute(self.legacy_update, (11, 1, 0, 1)), 0)
            cursor.execute(self.insert_sql, (100, 0, 1, "SqlTest", 1, 500))
        inventory, auctions = self.snapshot()
        self.assertEqual(inventory[1][2] + len(auctions), 12)
        self.reset(quantity=11)
        self.assert_rejected_without_changes(quantity=12)

    def test_reproduces_legacy_insert_retry_dupe(self):
        # Model a committed INSERT whose response was lost: the old database
        # retry path reissues the non-idempotent INSERT outside a transaction.
        with self.admin.cursor() as cursor:
            self.assertEqual(cursor.execute(self.legacy_delete, (1, 0, 1)), 1)
            for _ in range(2):
                cursor.execute(self.insert_sql, (100, 0, 1, "SqlTest", 1, 500))
        inventory, auctions = self.snapshot()
        self.assertEqual(len(inventory), 1)
        self.assertEqual(len(auctions), 2)
        self.reset()
        self.assert_interruption_rolls_back("insert")
        self.assertEqual(self.transfer(), "listed")
        self.assertEqual(len(self.snapshot()[1]), 1)


if __name__ == "__main__":
    unittest.main()
