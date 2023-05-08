// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './IKIP7.sol';
import './KIP13.sol';
import './IKIP7Metadata.sol';
import './Context.sol';
import './Address.sol';
import './IKIP7Receiver.sol';

/**
 * @dev Implementation of the {IKIP7} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {KIP7PresetMinterPauser}.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of KIP7
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IKIP7-approve}.
 *
 * See http://kips.klaytn.com/KIPs/kip-7-fungible_token
 */
contract KIP7 is Context, KIP13, IKIP7, IKIP7Metadata { 

    event AdminChanged(address indexed previousAdminAddress, address indexed newAdminAddress);
    event Burn(address indexed burner, uint256 value);

    address public adminAddress;
    string private _symbol;
    string private _name;
    uint8 private _decimals;

    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    bool public transferEnabled = false;
    mapping(address => uint256) private lockedAccounts;
	
    /**
     * @dev Throws if called by any account other than the adminAddress.
     */    
    modifier onlyAdmin() {
        require(_msgSender() == adminAddress, "onlyAdmin");
        _;
    }

    /**
     * Check if token transfer is allowed
     */
    modifier onlyWhenTransferAllowed() {
        require(transferEnabled == true
            || _msgSender() == adminAddress,
            "onlyWhenTransferAllowed");
        _;
    }

    /**
     * Check if token transfer destination is valid
     */
    modifier onlyValidDestination(address to) {
        require(to != address(0x0)
            && to != address(this)
            && to != adminAddress,
            "onlyValidDestination"
            );
        _;
    }

    /**
     * Check if the allowed amount is enough
     */
    modifier onlyAllowedAmount(address from, uint256 amount) {
		require(_balances[from] >= amount, "onlyAllowedAmount #1");
        require((_balances[from] - amount) >= lockedAccounts[from], "onlyAllowedAmount #2");
      _;
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0x0), _msgSender(), _totalSupply);
        adminAddress = _msgSender();
        approve(adminAddress, totalSupply_);
    }

    /**
     * @dev changes the adminAddress to newAdminAddress.
     * @param newAdminAddress new adminAddress.
     */
    function changeAdmin(address newAdminAddress) public 
        onlyAdmin 
        onlyValidDestination(newAdminAddress)
    {
        require(newAdminAddress != address(0), "newAdminAddress == address(0)");
        require(newAdminAddress != adminAddress, "newAdminAddress == adminAddress");        
        require(_balances[newAdminAddress] == 0, "Balance of new admin must be 0.");
        address oldAdminAddress = adminAddress;
        adminAddress = newAdminAddress;
        _balances[newAdminAddress] = _balances[oldAdminAddress];
        _balances[oldAdminAddress] = 0;
        emit AdminChanged(adminAddress, newAdminAddress);    
    }

    /**
     * Set transferEnabled variable to true
     */
    function enableTransfer() external onlyAdmin {
        transferEnabled = true;
    }

    /**
     * Set transferEnabled variable to false
     */
    function disableTransfer() external onlyAdmin {
        transferEnabled = false;
    }

    /**
     * @dev See {IKIP13-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(KIP13) returns (bool) {
        return
            interfaceId == type(IKIP7).interfaceId ||
            interfaceId == type(IKIP7Metadata).interfaceId ||
            KIP13.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {KIP7} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IKIP7-balanceOf} and {IKIP7-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IKIP7-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IKIP7-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IKIP7-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) 
		public 
		onlyWhenTransferAllowed 
        onlyValidDestination(to)
        onlyAllowedAmount(_msgSender(), amount)
		virtual 
		override 
		returns (bool) 
	{
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IKIP7-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IKIP7-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IKIP7-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {KIP7}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) 
		public 
		onlyWhenTransferAllowed
        onlyValidDestination(to)
        onlyAllowedAmount(from, amount)		
		virtual 
		override 
		returns (bool) 
	{
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IKIP7-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IKIP7-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev See {IKIP7-safeTransfer}.
     *
     * Emits a {Transfer} event
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * - if `recipient` is a smart contract, it must implement {IKIP7Receiver}
     */
    function safeTransfer(address to, uint256 amount) 
		public 
		onlyWhenTransferAllowed 
        onlyValidDestination(to)
        onlyAllowedAmount(_msgSender(), amount)
		virtual 
		override 
	{
        address owner = _msgSender();
        _safeTransfer(owner, to, amount, "");
    }

    /**
     * @dev Same as {xref-KIP7-safeTransfer-address-uint256-}[`safeTransfer`], with an additional `_data` parameter which is
     * forwarded in {IKIP7Receiver-onKIP7Received} to contract recipients.
     *
     * Emits a {Transfer} event
     */
    function safeTransfer(
        address to,
        uint256 amount,
        bytes memory _data
    )   public 
		onlyWhenTransferAllowed 
        onlyValidDestination(to)
        onlyAllowedAmount(_msgSender(), amount)
        virtual 
        override 
    {
        address owner = _msgSender();
        _safeTransfer(owner, to, amount, _data);
    }

    /**
     * @dev See {IKIP7-safeTransferFrom}.
     *
     * Emits a {Transfer} event
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the KIP. See the note at the beginning of {KIP7}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least `amount`.
     * - if `recipient` is a smart contract, it must implement {IKIP7Receiver}
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 amount
    )   public 
		onlyWhenTransferAllowed
        onlyValidDestination(to)
        onlyAllowedAmount(from, amount)	
        virtual 
        override 
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _safeTransfer(from, to, amount, "");
    }

    /**
     * @dev Same as {xref-KIP7-safeTransferFrom-address-uint256-}[`safeTransferFrom`], with an additional `_data` parameter which is
     * forwarded in {IKIP7Receiver-onKIP7Received} to contract recipients.
     *
     * Emits a {Transfer} event
     *
     * Emits an {Approval} event indicating the updated allowance.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 amount,
        bytes memory _data
    )   public 
		onlyWhenTransferAllowed
        onlyValidDestination(to)
        onlyAllowedAmount(from, amount)	
        virtual
        override 
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _safeTransfer(from, to, amount, _data);
    }

    /**
     * @dev Safely transfers `amout` token from `from` to `to`, checking first that contract recipients
     * are aware of the KIP7 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to` to be used
     * for additional KIP7 receiver handler logic
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - if `to` is a contract it must implement {IKIP7Receiver} and
     * - If `to` refers to a smart contract, it must implement {IKIP7Receiver}, which is called upon
     *   a safe transfer.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 amount,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, amount);
        require(_checkOnKIP7Received(from, to, amount, _data), "KIP7: transfer to non IKIP7Receiver implementer");
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public onlyAdmin {
        _burn(value);
    }

    /**
     * Disable transfering tokens more than allowed amount from certain account
     *
     * @param addr: Account to set allowed amount
     * @param amount: Amount of tokens to allow
     */
    function lockAccount(address addr, uint256 amount)
        external
        onlyAdmin
        onlyValidDestination(addr)
    {
        require(amount > 0, "amount must be bigger than 0");
        lockedAccounts[addr] = amount;
    }

    /**
     * Enable transfering tokens of locked account
     *
     * @param addr: Account to unlock
     */
    function unlockAccount(address addr)
        external
        onlyAdmin
        onlyValidDestination(addr)
    {
        lockedAccounts[addr] = 0;
    }	
	
    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */    
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
	
    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal function to invoke {IKIP7Receiver-onKIP7Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of transfer token amount
     * @param to target address that will receive the tokens
     * @param amount uint256 value to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnKIP7Received(
        address from,
        address to,
        uint256 amount,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IKIP7Receiver(to).onKIP7Received(_msgSender(), from, amount, _data) returns (bytes4 retval) {
                return retval == IKIP7Receiver.onKIP7Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("KIP7: transfer to non KIP7Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
	function _burn(uint256 amount) internal {
		require(amount <= _balances[_msgSender()], "burn amount exceeds balance");
    	require(_totalSupply >= amount, "burn amount exceeds totalSupply");

		address burner = _msgSender();

		_balances[burner] = _balances[burner] - amount;
		_totalSupply = _totalSupply - amount;
		emit Burn(burner, amount);
		emit Transfer(burner, address(0), amount);
	}

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");
        require(_balances[owner] >= amount, "amount is too big");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }	
}
