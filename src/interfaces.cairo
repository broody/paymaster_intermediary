use starknet::ContractAddress;

#[derive(Drop, Serde, Clone)]
pub enum PaymentType {
    Ticket,
    GoldenPass,
}

#[starknet::interface]
pub trait ITicketBooth<TContractState> {
    fn buy_game(
        ref self: TContractState,
        payment_type: PaymentType,
        player_name: Option<felt252>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn payment_token(self: @TContractState) -> ContractAddress;
    fn cost_to_play(self: @TContractState) -> u128;
}
