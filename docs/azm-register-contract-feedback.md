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

AZM can express the register part with `.asmi`, but it cannot currently express
that this specific service consumes and balances the helper's stack frame. In
strict mode that leaves `unknown_control_flow` / stack-balance findings on
routines that use `farCall` or `callBankService`.

TECM8 currently uses narrow `rc-ignore-next unknown_control_flow` comments at
those boundaries. They are not intended as the long-term ABI expression.

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
