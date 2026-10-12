**Auction-house item duplication: investigation, patch, and test evidence**

Investigation date: October 12, 2026.

The listing code had concrete persistence weaknesses that can create permanent duplicate items. A patch and regression tests have been added. **All 24 MariaDB integration tests passed. The exact player plug-pull exploit has not yet been reproduced or proven fixed through an actual FFXI client.** The nine added C++ test cases have not been compiled or executed in this environment.

**What was reported**

- Players disconnect by pulling their connection while listing an item on the auction house.
- After reconnecting, the item exists both in inventory and as an auction listing.
- The extra item survives another logout/login, according to the server operator.
- The server runs the latest version, according to the operator, and has AH Pagination enabled.

Those are operator observations. The investigation did not have production incident logs, a captured client reproduction, or access to the live database to independently trace a particular duplicated item.

**What the source showed about disconnects**

Inventory quantity changes are written to `char_inventory` immediately. They do not normally wait for a periodic character save. The disconnect persistence path in [persist_batch.cpp](src/map/persist_batch.cpp) saves other character state, such as position, effects, equipment, appearance, and variables; it does not restore an earlier inventory snapshot.

The inspected login and map-session code also contains checks against overlapping character sessions. No direct path was identified that explains why an ordinary client disconnect would roll this checkout's inventory back while preserving an auction listing.

Consequently, the original explanation of a slight character rollback remains unconfirmed. The patch addresses demonstrated listing-integrity defects, but the step connecting a player plug pull to those defects still needs investigation on a running server.

**Finding 1: an item transaction was not a database transaction**

The listing handler is named `auctionutils::ProofOfPurchase`, despite handling items being put up for sale. Before the patch, its essential sequence was:

1. Claim the inventory item through `ItemClaimTransaction`.
2. Deduct the auction fee through `pay()`.
3. Check the listing limit.
4. Remove the item or reduce its stack through `take()`.
5. Insert a row into `auction_house`.
6. Commit the C++ item transaction and send the success response.

`ItemClaimTransaction` manages item claims and undo operations. Its `pay()` and `take()` methods perform database writes as they run. Its `commit()` does not make those writes and the auction INSERT one SQL transaction.

That distinction matters when a write fails, a database connection is lost, or a process stops between operations. Inventory, gil, and auction state could be saved separately. Because the old code removed the inventory item before inserting the listing, a simple interruption in that order could also cause item loss. Separate writes alone do not prove the reported client-disconnect duplication mechanism.

Relevant code: [item_claim.cpp](src/map/items/transactions/item_claim.cpp), [transaction.cpp](src/map/items/transaction.cpp), and [auctionutils.cpp](src/map/utils/auctionutils.cpp).

**Finding 2: removing zero database rows could still authorize a listing**

The shared inventory mutation helper checked whether SQL execution returned a result. It did not require that exactly one inventory row had actually changed. Its old UPDATE and DELETE predicates identified the character, container, and slot, without matching the expected item ID and original quantity.

A successfully executed DELETE that affects zero rows is not proof that an item was consumed. Two concrete failure cases were reproduced with MariaDB:

| Reproduction setup | Old SQL outcome | Patched SQL outcome |
| --- | --- | --- |
| The character remembers an item in slot 1, but its saved row is now in slot 2. | DELETE of slot 1 affects zero rows; INSERT still creates an auction. One saved item and one listing remain. | The guarded removal fails; no listing or fee deduction is committed. |
| The character remembers a stack of 12, but the database holds 11. | Listing one writes quantity 11 again and inserts a single-item auction. The saved total rises from 11 to 12. | The original-quantity check fails; inventory and gil remain unchanged. |

The tests deliberately create those stale states. They demonstrate permanent duplication from the old SQL, verified through fresh database connections. **They do not establish how a player disconnect creates that stale state on the live server.**

The shared inventory helper remains unchanged. The new ownership and affected-row checks protect the auction listing path; this is not a claim that every inventory system has been repaired.

**Finding 3: a standalone auction INSERT could be retried twice**

[CachingDatabase::runWithRetry](src/common/database/caching_database.cpp) can reconnect and retry a statement after a database connection error. An INSERT into `auction_house` creates a new row each time it executes.

If the database commits the first INSERT but its response is lost, retrying that INSERT can create a second auction even though the source item was removed only once.

The SQL regression reproduces the resulting duplicate by removing one item and executing the old INSERT twice. This models an ambiguous retry; it does not reproduce an actual lost database response through the native C++ driver. A player's client connection dropping is also different from the map server's database connection dropping.

The existing database layer already suppresses reconnect-and-retry while `db::transaction` is active, including its COMMIT and ROLLBACK. The patch uses that existing protection rather than introducing a new retry mechanism.

**How the listing patch works**

The revised [ProofOfPurchase](src/map/utils/auctionutils.cpp) uses `ItemClaimTransaction` only to claim the item. It performs the persistent transfer inside one `db::transaction`:

1. Lock the seller's gil row with `SELECT ... FOR UPDATE`. Verify that its saved identity and balance match the character's inventory. This serializes listings for that seller even when listing fees are zero.
2. Read the seller's listing count and enforce the configured limit. A failed count query is treated as an error, not as zero listings.
3. DELETE the source row, or UPDATE a partial stack, only when character, container, slot, item ID, original quantity, and `bazaar = 0` all match. Require exactly one affected row.
4. Deduct a nonzero fee with a guarded UPDATE and require exactly one affected row. Skip this UPDATE for a zero fee, avoiding a false failure from an unchanged balance.
5. Insert the auction listing and require exactly one affected row.
6. Commit the SQL transaction.
7. Apply the resulting inventory quantities to the character in memory and send inventory updates and auction success packets.

The successful path retains item-drop hooks and equipment resynchronization behavior when an entire inventory entry is removed.

The handler also rejects a shutting-down character, slot zero, out-of-range inventory indices before narrowing them to an 8-bit slot, malformed stack flags, currency items, and empty item quantities. Existing restrictions on auction-ineligible items, partially used charged items, full-stack quantities, and insufficient gil remain in effect.

The intended persistent outcomes are:

| Outcome | Inventory and fee | Auction listing |
| --- | --- | --- |
| Transaction rolls back | Original inventory and gil remain | No new listing |
| Transaction commits | Listed quantity removed and fee charged once | One new listing |
| Commit result cannot be determined by the server | Character is disconnected and must reload authoritative state | No speculative refund or second INSERT |

Both relevant tables use InnoDB in the repository schema: [char_inventory.sql](sql/char_inventory.sql) and [auction_house.sql](sql/auction_house.sql). The live server's table engines and durability configuration were not inspected. No schema migration was added.

**Why failure handling forces a reload**

A failed COMMIT response does not prove that the database rejected the COMMIT. Giving the item or gil back in that situation can manufacture another copy after a successful listing.

The patched handler therefore calls `ForceLogout` on SQL transaction failure or a detected persisted-state mismatch. It leaves recovery to the database state loaded on login. Ordinary rejections such as insufficient gil or reaching the listing limit still use the normal failure path.

The patch deliberately avoids mixing SQL rollback with the existing `pay()`/`take()` undo operations. Those undos perform compensating SQL writes. For example, restoring a fully removed item through an INSERT after SQL rollback has already restored the row can collide with that existing row and leave memory inconsistent.

`ForceLogout` alone previously did not prevent later packets from the same incoming bundle from reaching handlers. [PacketSystem::dispatch](src/map/packet_system.cpp) now rejects further player packets while the character's status is `Shutdown`. This prevents subsequent inventory requests from using an uncertain in-memory state. The guard applies to all dispatched player packets during shutdown, not just auction packets.

**What was found about AH Pagination**

[ah_pagination.cpp](modules/custom/cpp/ah_pagination.cpp) intercepts the sales-information/display action (`Info`). It does not replace the listing action (`LotIn`), which still reaches the core listing handler. Packet validation occurs before module interception. Pagination was not identified as the writer creating the duplicate item.

Two related core issues were corrected:

- The listing limit is now read as `uint32`, matching larger configured limits instead of truncating them to 8 bits.
- The success response uses a slot in the currently displayed history page and appends the new entry when space remains. The old response used the seller's total listing count as a client slot, which can exceed the client's seven visible slots when pagination is enabled.

The pagination module itself was not changed. Static review also found these separate, unresolved issues:

| Module observation | Potential effect | Status |
| --- | --- | --- |
| A query result is dereferenced through `rset->rowsCount()` without a null check. | A database query failure can cause a crash. | Not patched or reproduced in this work. |
| `totalPages_` is an 8-bit value. | Large configured limits can overflow. For example, a limit of 1530 calculates 256 pages, which truncates to zero and makes page advancement's modulo operation invalid. | Not patched or reproduced in this work. |
| Page count uses `(limit / 6) + 1`. | Exact multiples of six include an extra configured page. | Not patched. |
| Displayed page count follows the configured ceiling rather than occupied pages. | The displayed total can exceed the number of populated pages; an existing TODO describes this. | Not patched. |

None of those additional module observations was demonstrated to cause the reported persistent duplication. The new tests do not execute the pagination module itself.

**Database tests that were actually executed**

[tools/tests/test_auction_listing.py](tools/tests/test_auction_listing.py) ran against an isolated MariaDB 11.4.5 instance using InnoDB tables. The run completed in 5.053 seconds:

```text
Tests run: 24
Failures:   0
Errors:     0
Skipped:    0
Result:    OK
```

| Coverage group | Tests | What was checked |
| --- | ---: | --- |
| Successful transfers | 4 | Single item, whole stack, one item from a stack, and zero fee. |
| Stale or unavailable source state | 6 | Missing source, wrong item, wrong quantity, stale partial stack, bazaar item, and stale gil. |
| Listing limit | 1 | Rejection preserves inventory and gil. |
| Database disconnection and retry | 6 | Abrupt TCP loss after source removal, fee deduction, and listing INSERT; partial-stack rollback; committed state survives reconnection; stale retry after a committed transfer is rejected. |
| Concurrent attempts | 4 | Competing single-item, full-stack, and partial-stack requests; concurrent attempts at the listing cap. |
| Old-SQL duplicate reproductions | 3 | Stale slot, stale quantity, and repeated INSERT produce duplicates; the corresponding guarded transfer checks prevent those outcomes. |

Every state assertion opens a fresh database connection. The helper was shut down after testing; no production database was accessed.

The six listing SQL statements are extracted directly from the current C++ source. The Python harness executes those statements in the intended order against simplified InnoDB test tables. It does **not** execute the C++ handler, native driver retry logic, production triggers, or an FFXI client.

The abrupt disconnect tests close the database TCP transport without an explicit rollback. The after-COMMIT disconnect test closes it after a successful COMMIT reply. An actual lost COMMIT reply is modeled in the C++ suite described below, which has not been run.

Local result artifacts are available under ignored build output and are not part of the tracked patch:

- [unittest-results.log](build/ah-validation/sql-db/unittest-results.log)
- [regression-results.json](build/ah-validation/sql-db/regression-results.json)

**C++ tests added but not executed**

[src/test/tests/auction_listing_tests.cpp](src/test/tests/auction_listing_tests.cpp) adds nine Catch2 test cases, registered in [src/test/CMakeLists.txt](src/test/CMakeLists.txt):

1. Inventory and fee transfer only after SQL commit.
2. Failures at transaction start, listing count, inventory removal, fee debit, INSERT, and COMMIT preserve the original state. The failure matrix covers both full removal and a partial-stack UPDATE.
3. Stale persisted inventory or gil is rejected.
4. A COMMIT that succeeds but loses its reply is not refunded.
5. A changed saved inventory slot cannot create an additional listing.
6. An invalid wider inventory index is rejected before narrowing.
7. An uncertain commit blocks a subsequent sort packet; a live-character control permits that packet.
8. A completed transfer cannot be repeated through a duplicate request or stale second character object.
9. Zero fees, limits above 255, listing-cap rejection, and displayed history handling work as intended.

These tests call the real C++ listing handler using a fake transactional database backend with injected failures. That backend also understands the old inventory statements, so the stale-slot test is designed to expose the previous duplicate rather than merely reject an unknown SQL string.

There was no configured C++ compiler/build toolchain available here, so no executable baseline-versus-patch result is claimed for this suite. Its character fixture is not registered in a running zone; it does not validate zone lifecycle, item-claim release, or repeated partial-stack sales in a live zone.

`git diff --check` and Python syntax checks passed. These checks do not replace compilation, the full repository checks, or a client reproduction.

**Files changed by the implementation**

| File | Change |
| --- | --- |
| [src/map/utils/auctionutils.cpp](src/map/utils/auctionutils.cpp) | Atomic, guarded listing transfer; conservative failure handling; input checks; larger listing limits; page-local history response. |
| [src/map/packet_system.cpp](src/map/packet_system.cpp) | Reject further packets while the character is shutting down. |
| [src/test/tests/auction_listing_tests.cpp](src/test/tests/auction_listing_tests.cpp) | Nine C++ handler regression cases. |
| [src/test/CMakeLists.txt](src/test/CMakeLists.txt) | Register the new C++ tests in `xi_test`. |
| [tools/tests/test_auction_listing.py](tools/tests/test_auction_listing.py) | Runnable MariaDB regression suite. |

No production deployment, database repair, or removal of existing duplicates was performed. Auction buying, cancellation, and other inventory workflows are not covered by this listing fix.

**How to rerun the database tests**

Start a disposable local MariaDB instance, install PyMySQL in the chosen Python environment, and set `AH_TEST_MYSQL_PORT` to that instance's port. The script connects only to `127.0.0.1`, reads no production configuration, and creates and drops its own randomly named database. The supplied database account needs permission to do that.

For example, in PowerShell, with a disposable instance listening on port 3307:

```powershell
python -m pip install PyMySQL
$env:AH_TEST_MYSQL_PORT = "3307"
python -m unittest discover -s tools/tests -p test_auction_listing.py -v
```

Optional `AH_TEST_MYSQL_USER` and `AH_TEST_MYSQL_PASSWORD` override the defaults of `root` and an empty password. Without PyMySQL or the port variable, the tests are skipped; a skipped run is not a successful validation of the fix.

On a configured build machine, build `xi_map` and `xi_test`, then run `xi_test` in the normal test environment. The added Catch2 cases run during its C++ test phase. A C++ build and those test results remain outstanding.

**What is required to close the original incident**

1. Compile the patched server and run the C++ tests and required repository checks.
2. Confirm the live inventory and auction tables use a transactional engine. The repository definitions are InnoDB, but that does not establish the live schema.
3. Use a staging server with the same modules and AH settings, including pagination. Reproduce the operator's actual listing-and-plug-pull sequence with a single item, a full stack, and a single item taken from a stack.
4. After reconnecting, check the saved inventory and auction quantities, fee balance, and ability to trade or relist any apparent extra copy. Repeat a logout/login to verify persistence. Total item units across inventory and active listings must be conserved.
5. Capture map logs and the relevant database rows around any failed attempt. This is needed to determine how the reported disconnect produces stale inventory or another inconsistent state.
6. After validation, deploy the rebuilt map binary to every map process and restart them. This is a C++ change; reloading Lua or toggling the pagination module does not activate it.

No retail packet captures or actual FFXI client sessions were used in this investigation. The evidence supports the guarded SQL transfer and demonstrates real duplicate outcomes in the old SQL. It does not yet support declaring the reported client plug-pull exploit resolved end to end.
