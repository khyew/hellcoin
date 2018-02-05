pragma solidity ^0.4.19;

/*
    Maximum evil version of the Hellhole scheme. Has the following modifications:
    - No minimum contribution.
    - 10% of the pool is awarded to the last 100 bidders equally.
    - The remainder is distributed among the investors who gave the last 10% of the pot's total wealth.
        - Their distribution is proportional to the amount they gave.
        - (UNIMPLEMENTED) Every ether also returns up to 1000 ethers on any investment they've held in the past.
            -For example, if you invested 1000 ether and give 1 ether in the last 10%, you will receive 1000 ether back before getting your share of the pot.
    - The time extension is based on an exponentially weighted moving average of the time interval between bids.
        - It has a minimum of 15 minutes.
*/
contract Styx {

    //Absolute end time for the contract, after which winners can collect payout.
    uint public end_time;
    //Total pot kept by the contract.
    uint public pot = 0;

    //Initialization
    function Styx() public payable {
        end_time = now + 24 hours;
        //Summon Moloch with a sacrifice of money
        pot += msg.value;
    }


    //Book keeping for payouts
    struct Sacrifice {
        address sender;
        uint amount;
        uint potSize;
        bool paid;
    }
    Sacrifice[] sacrifices;

    //Insert money here
    function sacrifice() public payable {
        require(now <= end_time);

        uint new_end_time = now + time_extension();
        if(new_end_time > end_time){
            end_time = new_end_time;
        }

        pot += msg.value;
        sacrifices.push(Sacrifice({
                sender: msg.sender,
                amount: msg.value,
                potSize: pot,
                paid: false
        }));
    }

    //Track and calculate time extension
    //An exponentially weighted moving average of time between sacrifices (in seconds)
    uint public interval_moving_average = 1 hours;
    //The timestamp of the last payment
    uint public last_pay_time = now;

    function time_extension() private returns (uint) {
        //Update the moving average estimate
        uint memory_portion = interval_moving_average * 19 / 20;
        uint new_portion = (now - last_pay_time) * 1 / 20;
        interval_moving_average = memory_portion + new_portion;
        last_pay_time = now;
        //Calculate the time extension period.
        uint period = interval_moving_average * 30;
        if(period < 15 minutes){
            return 15 minutes;
        } else {
            return period;
        }
    }

    //Withdrawals!
    function withdraw(uint sacrificeIndex) public {
        require(now > end_time);
        require(sacrificeIndex >= 0);
        require(sacrificeIndex < sacrifices.length);

        Sacrifice storage withdrawal = sacrifices[sacrificeIndex];

        require(withdrawal.sender == msg.sender);
        require(withdrawal.paid == false);

        withdrawal.paid = true;

        uint last100Payout = 0;
        if(sacrifices.length - sacrificeIndex < 100){
            uint last100Pot = pot * 1 / 10;
            last100Payout += last100Pot * 1 / 100;
        }

        uint last10Percent = pot * 1 / 10;
        uint last10PercentPayout = 0;
        if(withdrawal.potSize > pot - last10Percent){
            uint last10PercentPot = pot * 9 / 10;
            uint payoutPerWei = last10PercentPot / last10Percent;
            last10PercentPayout = withdrawal.amount * payoutPerWei;
        }

        uint winnings = last100Payout + last10PercentPayout;
        msg.sender.transfer(winnings);
    }
}
