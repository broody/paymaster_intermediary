use starknet::ContractAddress;

const PAYMASTER_ROLE: felt252 = selector!("PAYMASTER_ROLE");

#[starknet::interface]
pub trait IPaymasterIntermediary<TContractState> {
    fn set_ls_contracts(ref self: TContractState, ticket_booth: ContractAddress);
    fn set_treasury(ref self: TContractState, treasury: ContractAddress);
    fn buy_game_via_paymaster(ref self: TContractState, to: ContractAddress) -> u64;
    fn add_paymaster(ref self: TContractState, paymaster: ContractAddress);
    fn remove_paymaster(ref self: TContractState, paymaster: ContractAddress);
}

#[starknet::contract]
mod PaymasterIntermediary {
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::access::accesscontrol::interface::IAccessControl;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::interfaces::{ITicketBoothDispatcher, ITicketBoothDispatcherTrait, PaymentType};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        treasury: ContractAddress,
        ticket_booth: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
    }

    #[abi(embed_v0)]
    impl PaymasterIntermediaryImpl of super::IPaymasterIntermediary<ContractState> {
        fn set_ls_contracts(ref self: ContractState, ticket_booth: ContractAddress) {
            self.ownable.assert_only_owner();
            self.ticket_booth.write(ticket_booth);
        }
        
        fn buy_game_via_paymaster(ref self: ContractState, to: ContractAddress) -> u64 {
            let caller = get_caller_address();

            assert!(self.accesscontrol.has_role(super::PAYMASTER_ROLE, caller), "Caller is not a paymaster");

            let dungeon_ticket = ITicketBoothDispatcher {
                contract_address: self.ticket_booth.read()
            }.payment_token();

            let cost_to_play: u256 = ITicketBoothDispatcher {
                contract_address: self.ticket_booth.read()
            }.cost_to_play().into();

            IERC20Dispatcher { 
                contract_address: dungeon_ticket
            }.transfer_from(self.treasury.read(), get_contract_address(), cost_to_play);

            IERC20Dispatcher {
                contract_address: dungeon_ticket
            }.approve(self.ticket_booth.read(), cost_to_play);

            ITicketBoothDispatcher {
                contract_address: self.ticket_booth.read()
            }.buy_game(PaymentType::Ticket, Option::None, to, true)
        }

        fn set_treasury(ref self: ContractState, treasury: ContractAddress) {
            self.ownable.assert_only_owner();
            self.treasury.write(treasury);
        }

        fn add_paymaster(ref self: ContractState, paymaster: ContractAddress) {
            self.ownable.assert_only_owner();
            self.accesscontrol._grant_role(super::PAYMASTER_ROLE, paymaster);
        }

        fn remove_paymaster(ref self: ContractState, paymaster: ContractAddress) {
            self.ownable.assert_only_owner();
            self.accesscontrol._revoke_role(super::PAYMASTER_ROLE, paymaster);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }  
}