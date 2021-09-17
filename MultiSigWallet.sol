 pragma solidity 0.8.7;

 // SPDX-License-Identifier: MIT

 contract MultiSigWallet {

     event Deposit(address indexed sender, uint amount, uint balance);

     event SubmitTransaction(
         address indexed owner,
         uint indexed txIndex,
         address indexed to,
         uint value,
         bytes data
     );
     event ConfirmTransaction(address indexed owner, uint txIndex);
     event RevokeConfirmation(address indexed owner, uint txIndex);
     event ExecuteTransaction(address indexed owner, uint txIndex);

     address[] public owners;
     mapping(address => bool) public isOwner;
     uint public numConfirmationsRequired;

     struct Transaction{
         address to;
         uint value;
         bytes data;
         bool executed;
         uint numConfirmations;
     }

    mapping(uint => mapping(address => bool)) public isConfirmed;

     Transaction[] public transactions;

     constructor(address[] memory _owners, uint _numConfirmationsRequired) {
         require(_owners.length > 0, "owners required");
         require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "invalid number of required confirmations");
         require(_owners.length < 6, "maximum 5 owners");

         for( uint i = 0; i< owners.length; i++){
             address owner = _owners[i];
             require(owner != address(0), "inavalid owner");
             require(!isOwner[owner], "owners must be unique");
             isOwner[owner] = true;
             owners.push(owner);
         }

         numConfirmationsRequired = _numConfirmationsRequired;
     }

     receive () payable external {
         emit Deposit(msg.sender, msg.value, address(this).balance);
     }
    //for remix
     function deposit() payable external {
         emit Deposit(msg.sender, msg.value, address(this).balance);
     }

     modifier onlyOwner() {
         require(isOwner[msg.sender], "not owner");
         _;
     }

     function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
         uint txIndex = transactions.length;
         Transaction storage newTransaction = transactions.push();
         newTransaction.to = _to;
         newTransaction.value = _value;
         newTransaction.data = _data;
         newTransaction.executed = false;
         newTransaction.numConfirmations = 0;

         emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
     }

     modifier txExists(uint _txIndex){
         require(_txIndex < transactions.length, "tx does nto exist");
         _;
     }

     modifier notExecuted(uint _txIndex){
         require(!transactions[_txIndex].executed, "tx already executed");
         _;
     }

     modifier notConfirmed(uint _txIndex){
         require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
         _;
     }

     function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex){
         Transaction storage transaction = transactions[_txIndex];
         isConfirmed[_txIndex][msg.sender] = true;
         transaction.numConfirmations += 1;

         emit ConfirmTransaction(msg.sender, _txIndex);
     }

     function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex){
         Transaction storage transaction = transactions[_txIndex];
         require(transaction.numConfirmations >= numConfirmationsRequired, "cannot execute tx");

         transaction.executed = true;
         (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
         require(success, "tx failed");

         emit ExecuteTransaction(msg.sender, _txIndex);
     }

     function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex){
         require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");
         Transaction storage transaction = transactions[_txIndex];
         isConfirmed[_txIndex][msg.sender] = false;
         transaction.numConfirmations -= 1;

         emit RevokeConfirmation(msg.sender, _txIndex);
     }
 }