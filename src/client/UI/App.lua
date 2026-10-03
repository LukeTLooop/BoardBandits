--!strict
-- UI App

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- Types --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))
local WorkerShopTypes = require(sharedTypes:WaitForChild("WorkerShopTypes"))
local WorkerDetailsTypes = require(sharedTypes:WaitForChild("WorkerDetailsTypes"))
local WorkerUpgradeTypes = require(sharedTypes:WaitForChild("WorkerUpgradeTypes"))

-- UI --
local Screens = script.Parent:WaitForChild("Screens")
local WorkerShop = require(Screens:WaitForChild("WorkerShop"))
local WorkerInventory = require(Screens:WaitForChild("WorkerInventory"))
local WorkerDetails = require(Screens:WaitForChild("WorkerDetails"))

local e = React.createElement

-- Utility --
local utilities = script.Parent:WaitForChild("Utility")

local UISounds = require(utilities:WaitForChild("UISounds"))

-- Remotes --
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Workers")

local openWorkerShop = remotes:WaitForChild("OpenWorkerShop")
local requestWorkerShopState = remotes:WaitForChild("RequestWorkerShopState")
local buyWorker = remotes:WaitForChild("BuyWorker")

local openInventory = remotes:WaitForChild("OpenInventory")
local requestInventory = remotes:WaitForChild("RequestInventory")
local placeWorker = remotes:WaitForChild("PlaceWorker")

local openWorkerDetails = remotes:WaitForChild("OpenWorkerDetails")
local requestWorkerDetails = remotes:WaitForChild("RequestWorkerDetails")
local upgradeWorker = remotes:WaitForChild("UpgradeWorker")
local removeWorker = remotes:WaitForChild("RemoveWorker")
local inventoryUpdated = remotes:WaitForChild("InventoryUpdated")

assert(openWorkerShop:IsA("RemoteEvent"), "OpenWorkerShop must be a RemoteEvent!")
assert(requestWorkerShopState:IsA("RemoteFunction"), "RequestWorkerShopState must be a RemoteFunction!")
assert(buyWorker:IsA("RemoteFunction"), "BuyWorker must be a RemoteFunction!")

assert(openInventory:IsA("RemoteEvent"), "OpenInventory must be a RemoteEvent!")
assert(requestInventory:IsA("RemoteFunction"), "RequestInventory must be a RemoteFunction!")
assert(placeWorker:IsA("RemoteFunction"), "PlaceWorker must be a RemoteFunction!")

assert(openWorkerDetails:IsA("RemoteEvent"), "OpenWorkerDetails must be a RemoteEvent!")
assert(requestWorkerDetails:IsA("RemoteFunction"), "RequestWorkerDetails must be a RemoteFunction!")
assert(upgradeWorker:IsA("RemoteFunction"), "UpgradeWorker must be a RemoteFunction!")
assert(removeWorker:IsA("RemoteFunction"), "RemoveWorker must be a RemoteFunction!")
assert(inventoryUpdated:IsA("RemoteEvent"), "InventoryUpdated must be a RemoteEvent!")

-- App --
local function App()
	type PlacementTarget = {
		FactoryId: string,
		SlotIndex: number,
		StationRole: string,
	}

	local EMPTY_PLACEMENT_TARGET: PlacementTarget = {
		FactoryId = "",
		SlotIndex = 0,
		StationRole = "",
	}

	local shopOpen, setShopOpen = React.useState(false)
	local shopState, setShopState = React.useState(nil :: WorkerShopTypes.ShopState?)
	local purchasing, setPurchasing = React.useState(false)
	local statusMessage, setStatusMessage = React.useState("")

	local inventoryOpen, setInventoryOpen = React.useState(false)
	local inventoryWorkers, setInventoryWorkers = React.useState({} :: { WorkerTypes.ClientWorkerData })
	local placing, setPlacing = React.useState(false)
	local inventoryStatus, setInventoryStatus = React.useState("")
	local placementTarget, setPlacementTarget = React.useState(EMPTY_PLACEMENT_TARGET)

	local detailsOpen, setDetailsOpen = React.useState(false)
	local detailsSlotIndex, setDetailsSlotIndex = React.useState(0)
	local detailsData, setDetailsData = React.useState(nil :: WorkerDetailsTypes.DetailsData?)
	local detailsBusy, setDetailsBusy = React.useState(false)
	local detailsStatus, setDetailsStatus = React.useState("")

	-- Refresh
	local function refreshShop()
		local result = requestWorkerShopState:InvokeServer()

		setShopState(result :: WorkerShopTypes.ShopState)
	end

	local function refreshInventory()
		local result = requestInventory:InvokeServer()

		setInventoryWorkers(result :: { WorkerTypes.ClientWorkerData })
	end

	local function refreshWorkerDetails(slotIndex: number)
		local result = requestWorkerDetails:InvokeServer(slotIndex)

		setDetailsData(result :: WorkerDetailsTypes.DetailsData?)
	end

	-- Open listener
	React.useEffect(function()
		local connection = openWorkerShop.OnClientEvent:Connect(function()
			setShopOpen(true)
			setStatusMessage("")

			task.spawn(refreshShop)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = openInventory.OnClientEvent:Connect(
			function(factoryId: string, slotIndex: number, stationRole: string)
				-- Don't stack screens
				setShopOpen(false)
				setInventoryStatus("")
				setInventoryOpen(true)
				setPlacementTarget({
					FactoryId = factoryId,
					SlotIndex = slotIndex,
					StationRole = stationRole,
				})

				task.spawn(refreshInventory)
			end
		)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = openWorkerDetails.OnClientEvent:Connect(function(slotIndex: number)
			-- Close other screens
			setShopOpen(false)
			setInventoryOpen(false)

			-- Open details
			setDetailsSlotIndex(slotIndex)
			setDetailsData(nil)
			setDetailsStatus("")
			setDetailsOpen(true)

			task.spawn(function()
				refreshWorkerDetails(slotIndex)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = inventoryUpdated.OnClientEvent:Connect(function(workerId: string, newState: string)
			local current = detailsData
			if not current then
				return
			end

			if current.Id ~= workerId then
				return
			end

			-- Worker left this station
			if newState ~= "Placed" then
				setDetailsOpen(false)
				setDetailsSlotIndex(0)
				setDetailsData(nil)
				setDetailsStatus("")
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {
		detailsData,
	})

	-- Purchase
	local function handleBuy(workerType: string)
		if purchasing then
			return
		end
		setPurchasing(true)

		task.spawn(function()
			local result = buyWorker:InvokeServer(workerType) :: WorkerShopTypes.PurchaseResult
			setStatusMessage(result.Message)

			refreshShop()

			setPurchasing(false)
		end)
	end

	-- Place worker
	local function handlePlaceWorker(workerId: string)
		if placing then
			return
		end

		local target = placementTarget
		if target.SlotIndex <= 0 then
			return
		end

		local factoryId = target.FactoryId
		local slotIndex = target.SlotIndex

		if not factoryId or not slotIndex then
			return
		end

		setPlacing(true)

		task.spawn(function()
			local success = placeWorker:InvokeServer(workerId, slotIndex)

			if success == true then
				setInventoryOpen(false)
				setPlacementTarget(EMPTY_PLACEMENT_TARGET)
				setInventoryStatus("")
			else
				setInventoryStatus("COULD NOT ASSIGN WORKER")

				refreshInventory()
			end

			setPlacing(false)
		end)
	end

	-- Upgrade worker
	local function handleUpgradeWorker()
		if detailsBusy then
			return
		end

		local data = detailsData
		local slotIndex = detailsSlotIndex

		if not data or slotIndex <= 0 then
			return
		end

		if not data.Upgrade.CanUpgrade then
			return
		end

		setDetailsBusy(true)
		setDetailsStatus("")

		task.spawn(function()
			local result = upgradeWorker:InvokeServer(data.Id) :: WorkerUpgradeTypes.UpgradeResult

			if result.Success then
				UISounds.PlayWorkerUpgrade(result.UnlockedProductionTier)

				setDetailsStatus("WORKER UPGRADED!")

				refreshWorkerDetails(slotIndex)
			else
				setDetailsStatus("COULD NOT UPGRADE WORKER")

				refreshWorkerDetails(slotIndex)
			end

			setDetailsBusy(false)
		end)
	end

	-- Remove worker
	local function handleRemoveWorker()
		if detailsBusy then
			return
		end

		local slotIndex = detailsSlotIndex
		if slotIndex <= 0 then
			return
		end

		setDetailsBusy(true)
		setDetailsStatus("")

		task.spawn(function()
			local success = removeWorker:InvokeServer(slotIndex)

			if success == true then
				setDetailsOpen(false)

				setDetailsSlotIndex(0)
				setDetailsData(nil)

				-- Refresh storage for next time
				refreshInventory()
			else
				setDetailsStatus("COULD NOT REMOVE WORKER")
			end

			setDetailsBusy(false)
		end)
	end

	-- Render
	return e(React.Fragment, nil, {
		WorkerShop = e(WorkerShop, {
			Visible = shopOpen,

			State = shopState,

			StatusMessage = statusMessage,

			Purchasing = purchasing,

			OnClose = function()
				setShopOpen(false)
			end,

			OnBuy = handleBuy,
		}),

		WorkerInventory = e(WorkerInventory, {
			Visible = inventoryOpen,

			Workers = inventoryWorkers,

			StationRole = if placementTarget.SlotIndex > 0 then placementTarget.StationRole else nil,

			Placing = placing,

			StatusMessage = inventoryStatus,

			OnClose = function()
				setInventoryOpen(false)
				setPlacementTarget(EMPTY_PLACEMENT_TARGET)
				setInventoryStatus("")
			end,

			OnPlace = handlePlaceWorker,
		}),

		WorkerDetails = e(WorkerDetails, {
			Visible = detailsOpen,

			Data = detailsData,

			Busy = detailsBusy,

			StatusMessage = detailsStatus,

			OnClose = function()
				setDetailsOpen(false)
				setDetailsSlotIndex(0)
				setDetailsData(nil)
				setDetailsStatus("")
			end,

			OnUpgrade = handleUpgradeWorker,

			OnRemove = handleRemoveWorker,
		}),
	})
end

return App
