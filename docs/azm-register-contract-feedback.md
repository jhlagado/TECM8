# AZM Register Contract Feedback

This note records practical findings from applying AZM 0.2.13 register
contracts to the TECM8 banked expansion ROM.

## RST Service Contracts Work For Register Outputs

AZM's external `.asmi` service form can describe specific `RST 10h` services:

```text
service rst 0x10 C 0x53 MON_BANK_CALL
in B,HL
out A,carry
clobbers B,C,D,E,H,L,zero,sign,parity,halfCarry
end
```

That is useful for TECM8 because `RST 10h` is a normal Z80 call to the monitor,
with the selected service identified by `C`. The service-specific register
contract is part of the ABI.

## Missing Piece: Service Stack Effects

The remaining limitation is stack modelling. TECM8's `farCall` op pushes a
small frame before entering the monitor:

```asm
op farCall(bank imm8, target imm16)
        push hl
        push de
        push af
        ld b,bank
        ld hl,target
        ld c,MON_BANK_CALL
        rst 10H
end
```

Runtime behaviour is deliberate and balanced:

1. `RST 10h` enters the fixed monitor.
2. `C=MON_BANK_CALL` selects the monitor bank-call service.
3. The monitor uses the saved `AF`/`DE`/`HL` frame below the RST return address.
4. The target bank sees the original argument registers.
5. The target returns normally.
6. The monitor restores the previous `SYS_CTRL` and returns to the caller.
7. `SP` is back where it started, and target `A`/carry are returned.

Before AZM 0.2.14, AZM could express the register part with `.asmi`, but could
not express that this specific service consumes and balances the helper's stack
frame. In strict mode that left `unknown_control_flow` / stack-balance findings
on routines that use `farCall` or `callBankService`.

TECM8 temporarily used narrow `rc-ignore-next unknown_control_flow` comments at
those boundaries. AZM 0.2.15 removes the remaining need for those suppressions.

## Practical AZM Request

TECM8 would benefit from one of these mechanisms:

1. Extend `.asmi` service contracts with stack-effect clauses for service calls.
2. Allow op-level contracts, so `farCall` can declare that its expansion is
   stack-balanced overall and returns `A`/carry.
3. Allow a profile entry for `RST 10h` service `C=53h` to describe the monitor's
   stack-frame ABI.

A possible interface shape:

```text
service rst 0x10 C 0x53 MON_BANK_CALL
in B,HL
out A,carry
clobbers B,C,D,E,H,L,zero,sign,parity,halfCarry
stack balanced
consumes-frame AF,DE,HL
end
```

The goal is not to relax all `RST` instructions. The goal is to describe the
actual ABI of a specific monitor service selected by `C`.

## AZM 0.2.14 Test Result

AZM 0.2.14 adds the built-in `MON_BANK_CALL` stack-frame model and a first-pass
TecMate `C >= 60h` expansion-service fallback. The bank-call model removes the
need for suppressions around simple `farCall` and `callBankService` use, but
TECM8 still needs narrow `unknown_control_flow` suppressions in two dispatcher
shapes:

- `Tecm8ServiceCall` in bank 0 pushes a dispatcher frame, jumps to local service
  arms, pops the frame in each arm, and then calls `farCall`.
- `Tecm8ExpansionBank1Entry` saves `AF`, dispatches through conditional paths,
  restores `AF`, and tail-jumps to the target implementation.

Both are intentionally balanced, and the runtime proof still passes. The
remaining issue appears to be AZM's stack analysis across local dispatcher arms
and tail-dispatch paths, not the `RST 10h` CPU instruction itself.

The `C >= 60h` fallback is useful, but it currently preserves more registers than
TECM8's real expansion services guarantee. For now the project-local
`tecm8-rst-services.asmi` keeps explicit broad-clobber contracts for the known
service numbers, so callers cannot accidentally depend on `B/C/D/E/H/L`
surviving a service whose implementation may use them.

Current TECM8 verification on AZM 0.2.14:

```text
npm run rom:contracts:check
npm run proof:bank-abi
npm run typecheck
```

All pass with the temporary suppressions retained.

## AZM 0.2.15 Test Result

AZM 0.2.15 moves the TecMate `C >= 60h` expansion-service fallback out of the
built-in MON3 profile and lets TECM8 own that contract in
`tecm8-rst-services.asmi`. TECM8 now declares a broad-clobber range fallback for
`C >= 60h`, with exact entries for each current registered service:

```text
service rst 0x10 C >= 0x60 TECMATE_EXPANSION_SERVICE
in C
out A,carry
clobbers B,C,D,E,H,L,zero,sign,parity,halfCarry
end
```

The AZM 0.2.15 dispatcher/tail-dispatch stack proof also removes the need for
the two remaining `unknown_control_flow` suppressions around:

- `Tecm8ServiceCall`
- `Tecm8ExpansionBank1Entry`

That leaves `MON_BANK_CALL` modelled by the MON3 profile, TECM8 expansion
services modelled by the project `.asmi`, and the expansion ROM contract check
clean without temporary suppressions.

The exact service list is now tested by
`tools/tecm8-rst-services-interface.test.ts`. The broad `C >= 60h` entry remains
as the conservative fallback for genuinely unknown expansion services; registered
bank-0 services should have explicit entries so the project can tighten them one
by one as their ABIs settle.
