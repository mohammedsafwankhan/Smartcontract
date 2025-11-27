// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleWalletLog
/// @author
/// @notice Beginner wallet contract that logs deposits and withdrawals on-chain.
/// @dev No constructor inputs. Owner is deployer (msg.sender).
contract SimpleWalletLog {
    address public owner;

    enum TxType { Deposit, Withdrawal }

    struct Transaction {
        address user;       // who made the deposit/initiated withdrawal
        uint256 amount;     // amount in wei
        uint256 timestamp;  // block timestamp of the txn
        TxType txType;      // deposit or withdrawal
    }

    Transaction[] private transactions;

    event Deposited(address indexed from, uint256 amount, uint256 indexed index);
    event Withdrawn(address indexed to, uint256 amount, uint256 indexed index);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @notice Sets the deployer as the owner. No inputs required.
    constructor() {
        owner = msg.sender;
    }

    /// @notice Fallback to accept plain ETH transfers (calls deposit logic).
    receive() external payable {
        _logDeposit(msg.sender, msg.value);
    }

    fallback() external payable {
        _logDeposit(msg.sender, msg.value);
    }

    /// @notice Deposit ETH to the contract (explicit).
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        _logDeposit(msg.sender, msg.value);
    }

    /// @dev Internal helper to record deposit and emit event.
    function _logDeposit(address from, uint256 amount) internal {
        transactions.push(Transaction({
            user: from,
            amount: amount,
            timestamp: block.timestamp,
            txType: TxType.Deposit
        }));
        emit Deposited(from, amount, transactions.length - 1);
    }

    /// @notice Owner withdraws `amount` wei to their own address.
    /// @param amount Amount in wei to withdraw.
    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount > 0");
        require(address(this).balance >= amount, "Insufficient balance");

        // Record withdrawal BEFORE transfer to ensure on-chain log even if transfer fails later
        transactions.push(Transaction({
            user: msg.sender,
            amount: amount,
            timestamp: block.timestamp,
            txType: TxType.Withdrawal
        }));
        emit Withdrawn(msg.sender, amount, transactions.length - 1);

        // Transfer ETH to owner
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Transfer failed");
    }

    /// @notice Owner withdraws all contract balance to their address.
    function withdrawAll() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance");

        transactions.push(Transaction({
            user: msg.sender,
            amount: bal,
            timestamp: block.timestamp,
            txType: TxType.Withdrawal
        }));
        emit Withdrawn(msg.sender, bal, transactions.length - 1);

        (bool sent, ) = payable(msg.sender).call{value: bal}("");
        require(sent, "Transfer failed");
    }

    /// @notice Owner can send funds to a different address (e.g., pay a vendor).
    /// @param to Recipient address.
    /// @param amount Amount in wei to send.
    function withdrawTo(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount > 0");
        require(address(this).balance >= amount, "Insufficient balance");

        transactions.push(Transaction({
            user: to,
            amount: amount,
            timestamp: block.timestamp,
            txType: TxType.Withdrawal
        }));
        emit Withdrawn(to, amount, transactions.length - 1);

        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Transfer failed");
    }

    /// @notice Get total number of logged transactions.
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /// @notice Read a transaction by index.
    /// @param index Index in the transactions array (0..count-1).
    function getTransaction(uint256 index)
        external
        view
        returns (address user, uint256 amount, uint256 timestamp, TxType txType)
    {
        require(index < transactions.length, "Index out of bounds");
        Transaction storage t = transactions[index];
        return (t.user, t.amount, t.timestamp, t.txType);
    }

    /// @notice Convenience: get contract balance (in wei).
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

