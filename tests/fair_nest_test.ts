import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can list a property",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fair-nest', 'list-property', [
        types.ascii("Test Property"),
        types.ascii("Test Description"),
        types.uint(100000000),
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    const listing = chain.callReadOnlyFn(
      'fair-nest',
      'get-listing',
      [types.uint(1)],
      deployer.address
    );
    
    listing.result.expectSome();
  }
});

Clarinet.test({
  name: "Ensure can book a property",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // First list a property
    let block = chain.mineBlock([
      Tx.contractCall('fair-nest', 'list-property', [
        types.ascii("Test Property"),
        types.ascii("Test Description"),
        types.uint(100000000),
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    // Then try to book it
    block = chain.mineBlock([
      Tx.contractCall('fair-nest', 'book-property', [
        types.uint(1),
        types.uint(100),
        types.uint(105)
      ], wallet2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    const booking = chain.callReadOnlyFn(
      'fair-nest',
      'get-booking',
      [types.uint(1)],
      deployer.address
    );
    
    booking.result.expectSome();
  }
});

Clarinet.test({
  name: "Ensure can leave a review",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // List and book a property first
    let block = chain.mineBlock([
      Tx.contractCall('fair-nest', 'list-property', [
        types.ascii("Test Property"),
        types.ascii("Test Description"),
        types.uint(100000000),
        types.principal(wallet1.address)
      ], wallet1.address),
      Tx.contractCall('fair-nest', 'book-property', [
        types.uint(1),
        types.uint(100),
        types.uint(105)
      ], wallet2.address)
    ]);
    
    // Leave a review
    block = chain.mineBlock([
      Tx.contractCall('fair-nest', 'leave-review', [
        types.uint(1),
        types.uint(5),
        types.ascii("Great place!")
      ], wallet2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    const review = chain.callReadOnlyFn(
      'fair-nest',
      'get-review',
      [types.uint(1), types.principal(wallet2.address)],
      deployer.address
    );
    
    review.result.expectSome();
  }
});
