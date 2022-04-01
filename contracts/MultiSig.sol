//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract MyMultiSig {

    address[] public owners;
    uint public required;
    Transaction[] public transactions;
    mapping(address => bool) public isOwner;
    mapping(uint256 => uint256) public approvals;
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    struct Transaction {
        address _to;
        uint256 _value;
        bool executed;
    }

    event Receive(address indexed sender, uint256 value);
    event Submit(uint256 indexed txId);
    event Approve(address indexed approver, uint256 txId);
    event Revoke(address indexed revoker, uint256 txId);
    event Execute(uint256 txId);

    modifier onlyOwners() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length <= _required && _required > 1, "invalid required amount");
        require(_owners.length > 0, "invalid owners amount");

        uint length = owners.length;
        for (uint i; i < length;) {
            address owner = _owners[i];

            require(owner != address(0), "invalid address");
            require(!isOwner[owner], "owner is not unique");
            
            isOwner[owner] = true;
            owners.push(owner);
            unchecked { ++i; }
        }
        required = _required;
    }

    function submit(address _to, uint256 _value) public onlyOwners {
        transactions.push(Transaction(_to, _value, false));
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId) public onlyOwners {
        require(!hasApproved[_txId][msg.sender], "owner already approved");
        hasApproved[_txId][msg.sender] = true;

        approvals[_txId]++;
        emit Approve(msg.sender, _txId);
    }

    function revoke(uint256 _txId) public onlyOwners {
        require(hasApproved[_txId][msg.sender], "owner has not approved");
        approvals[_txId]--;
        hasApproved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    function execute(uint256 _txId) public onlyOwners {
        require(approvals[_txId] >= required, "required approvals not met");
        Transaction storage transaction = transactions[_txId];
        require(!transaction.executed, "transaction already executed");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = transaction._to.call{value: transaction._value}("");
        require(success, "tx failed"); 
        emit Execute(_txId);
    }

    receive() external payable {
        emit Receive(msg.sender, msg.value);
    }
}
