--!strict
-- Passive HUD

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- Shared --
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemConfig = require(Shared.Config:WaitForChild("ItemConfig"))
local WorkerConfig = require(Shared.Config:WaitForChild("WorkerConfig"))
local ProgressionConfig = require(Shared.Config:WaitForChild("ProgressionConfig"))
local HUDTypes = require(Shared.Types:WaitForChild("HUDTypes"))

local NumberFormatUtil = require(Shared.Utility:WaitForChild("NumberFormatUtil"))

-- HUD --
local HUDAssets = require(script.Parent:WaitForChild("HUDAssets"))

local HUDButton = require(script.Parent:WaitForChild("HUDButton"))
local HUDDrawer = require(script.Parent:WaitForChild("HUDDrawer"))
local StatDisplay = require(script.Parent:WaitForChild("StatDisplay"))

-- Theme --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local e = React.createElement

-- Props --
type Props = {
	Visible: boolean,
	State: HUDTypes.HUDState?,
}

type InventoryEntry = {
	ItemId: string,
	Amount: number,
}

-- Drawer row
local function DrawerRow(label: string, value: string, layoutOrder: number, accentColor: Color3?)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 42),

		BackgroundColor3 = Color3.fromRGB(230, 221, 198),

		BorderSizePixel = 0,

		LayoutOrder = layoutOrder,

		ZIndex = 4,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),

		Accent = e("Frame", {
			Size = UDim2.new(0, 6, 1, 0),

			BackgroundColor3 = accentColor or Theme.Color.Yellow,

			BorderSizePixel = 0,

			ZIndex = 5,
		}),

		Label = e("TextLabel", {
			Position = UDim2.fromOffset(15, 0),

			Size = UDim2.new(0.65, -15, 1, 0),

			BackgroundTransparency = 1,

			Text = label,

			TextColor3 = Theme.Color.Ink,

			TextSize = 14,

			Font = Enum.Font.GothamBold,

			TextXAlignment = Enum.TextXAlignment.Left,

			ZIndex = 5,
		}),

		Value = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),

			Position = UDim2.new(1, -10, 0, 0),

			Size = UDim2.new(0.35, -22, 1, 0),

			BackgroundTransparency = 1,

			Text = value,

			TextColor3 = Theme.Color.Ink,

			TextSize = 15,

			Font = Enum.Font.FredokaOne,

			TextXAlignment = Enum.TextXAlignment.Right,

			ZIndex = 5,
		}),
	})
end

local function getInventoryDelta(previousInventory: { [string]: number }, nextInventory: { [string]: number }): number
	local delta = 0

	for itemId, amount in nextInventory do
		local previousAmount = previousInventory[itemId] or 0

		if amount > previousAmount then
			delta += amount - previousAmount
		end
	end

	return delta
end

local function getWorkerDelta(
	previousWorkers: { HUDTypes.WorkerSummary },
	nextWorkers: { HUDTypes.WorkerSummary }
): number
	local previousLevels: { [string]: number } = {}

	for _, worker in previousWorkers do
		previousLevels[worker.Id] = worker.Level
	end

	local delta = 0

	for _, worker in nextWorkers do
		local previousLevel = previousLevels[worker.Id]

		if previousLevel == nil then
			delta += 1
		elseif worker.Level > previousLevel then
			delta += worker.Level - previousLevel
		end
	end

	return delta
end

-- Passive HUD
local function PassiveHUD(props: Props)
	local openDrawer, setOpenDrawer = React.useState("")
	local inventoryUnread, setInventoryUnread = React.useState(0)
	local workerUnread, setWorkerUnread = React.useState(0)
	local viewportSize, setViewportSize = React.useState(Vector2.new(1440, 900))

	local previousStateRef = React.useRef(nil :: HUDTypes.HUDState?)

	-- Viewport tracking
	React.useEffect(function()
		local viewportConnection: RBXScriptConnection? = nil

		local cameraConnection: RBXScriptConnection? = nil

		local function updateViewport()
			local camera = workspace.CurrentCamera

			if camera then
				setViewportSize(camera.ViewportSize)
			end
		end

		local function bindCamera()
			if viewportConnection then
				viewportConnection:Disconnect()
			end

			local camera = workspace.CurrentCamera

			if camera then
				viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewport)
			end

			updateViewport()
		end

		bindCamera()

		cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

		return function()
			if viewportConnection then
				viewportConnection:Disconnect()
			end

			if cameraConnection then
				cameraConnection:Disconnect()
			end
		end
	end, {})

	-- Close drawers when HUD disappears
	React.useEffect(function()
		if not props.Visible then
			setOpenDrawer("")
		end

		return nil
	end, {
		props.Visible,
	})

	React.useEffect(function()
		if openDrawer == "Inventory" then
			setInventoryUnread(0)
		elseif openDrawer == "Workers" then
			setWorkerUnread(0)
		end

		return nil
	end, {
		openDrawer,
	})

	React.useEffect(
		function()
			local currentState = props.State
			local previousState = previousStateRef.current

			if currentState and previousState then
				if openDrawer ~= "Inventory" then
					local inventoryDelta =
						getInventoryDelta(previousState.FactoryInventory, currentState.FactoryInventory)

					if inventoryDelta > 0 then
						setInventoryUnread(function(current)
							return current + inventoryDelta
						end)
					end
				end

				if openDrawer ~= "Workers" then
					local workerDelta = getWorkerDelta(previousState.Workers, currentState.Workers)

					if workerDelta > 0 then
						setWorkerUnread(function(current)
							return current + workerDelta
						end)
					end
				end
			end

			previousStateRef.current = currentState

			return nil
		end,
		{
			props.State,
			openDrawer,
		} :: { any }
	)

	if not props.Visible then
		return nil
	end

	local state = props.State
	local mobile = viewportSize.X <= 800
	local hasFactory = state ~= nil and state.HasFactory
	local playerCash = if state then state.PlayerCash else 0
	local factoryCash = if state then state.FactoryCash else 0
	local placedWorkers = if state then state.PlacedWorkers else 0
	local totalWorkers = if state then state.TotalWorkers else 0

	-- Inventory totals
	local inventoryTotal = 0

	if state then
		for _, amount in state.FactoryInventory do
			inventoryTotal += amount
		end
	end

	-- Automation totals
	local totalAutomation = 0
	local automationRates: { [string]: number } = {}

	if state then
		for _, worker in state.Workers do
			local outputItem = worker.OutputItem

			local rate = worker.OutputPerMinute

			if not outputItem or not rate then
				continue
			end

			totalAutomation += rate

			automationRates[outputItem] = (automationRates[outputItem] or 0) + rate
		end
	end

	-- Inventory drawer
	local inventoryEntries: { InventoryEntry } = {}

	if state then
		for itemId, amount in state.FactoryInventory do
			if amount <= 0 then
				continue
			end

			table.insert(inventoryEntries, {
				ItemId = itemId,

				Amount = amount,
			})
		end
	end

	table.sort(inventoryEntries, function(a: InventoryEntry, b: InventoryEntry)
		local aDefinition = ItemConfig[a.ItemId]
		local bDefinition = ItemConfig[b.ItemId]

		local aName = if aDefinition then aDefinition.DisplayName else a.ItemId
		local bName = if bDefinition then bDefinition.DisplayName else b.ItemId

		return aName < bName
	end)

	local inventoryChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 7),

			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if #inventoryEntries == 0 then
		inventoryChildren.Empty = DrawerRow(
			if hasFactory then "Factory Stash" else "Claim A Factory",
			if hasFactory then "EMPTY" else "LOCKED",
			1,
			Theme.Color.Bearings
		)
	else
		for index, entry in inventoryEntries do
			local definition = ItemConfig[entry.ItemId]

			inventoryChildren[entry.ItemId] = DrawerRow(
				if definition then definition.DisplayName else entry.ItemId,
				`x{NumberFormatUtil.Format(entry.Amount)}`,
				index,
				Theme.Color.Bearings
			)
		end
	end

	if state then
		local requiredParts = ProgressionConfig.WorkerShop.RequiredPartsSold

		inventoryChildren.Progress = DrawerRow(
			"Parts Sold",
			if state.WorkerShopUnlocked then "DEPOT OPEN" else `{state.PartsSold}/{requiredParts}`,
			1000,
			Theme.Color.Yellow
		)
	end

	local inventoryContent = e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		CanvasSize = UDim2.new(),

		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		ScrollBarThickness = 5,

		ScrollBarImageColor3 = Theme.Color.Ink,

		ZIndex = 4,
	}, inventoryChildren)

	-- Worker drawer
	local workerChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 7),

			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if not state or #state.Workers == 0 then
		workerChildren.Empty = DrawerRow("Placed Workers", "NONE", 1, Theme.Color.Assembler)
	else
		for index, worker in state.Workers do
			local definition = WorkerConfig[worker.WorkerType]
			local displayName = if definition then definition.DisplayName else worker.WorkerType
			local roleName = if definition then definition.RoleName else worker.RoleName
			local roleColor = Theme.RoleColors[roleName] or Theme.Color.Assembler
			local status = `LV.{worker.Level}`

			if worker.OutputPerMinute then
				status ..= ` • {NumberFormatUtil.Format(worker.OutputPerMinute)}/MIN`
			end

			workerChildren[worker.Id] = DrawerRow(`{displayName} • {roleName}`, status, index, roleColor)
		end
	end

	local automationItemIds: { string } = {}

	for itemId in automationRates do
		table.insert(automationItemIds, itemId)
	end

	table.sort(automationItemIds)

	for index, itemId in automationItemIds do
		local definition = ItemConfig[itemId]

		workerChildren[`Automation_{itemId}`] = DrawerRow(
			if definition then `⚙ {definition.DisplayName}` else `⚙ {itemId}`,
			`{NumberFormatUtil.Format(automationRates[itemId])}/MIN`,
			500 + index,
			Theme.Color.Wheels
		)
	end

	local workerContent = e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		CanvasSize = UDim2.new(),

		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		ScrollBarThickness = 5,

		ScrollBarImageColor3 = Theme.Color.Ink,

		ZIndex = 4,
	}, workerChildren)

	-- Sizing
	local statWidth = if mobile then math.max(150, math.floor(viewportSize.X * 0.43)) else 300
	local statHeight = if mobile then 55 else 70
	local buttonWidth = if mobile then 158 else 205
	local buttonHeight = if mobile then 60 else 72
	local drawerWidth = if mobile then viewportSize.X - 24 else 330
	local drawerHeight = if mobile then math.min(420, viewportSize.Y - 145) else 350

	-- Render
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		ZIndex = 20,
	}, {
		-- Edge buttons
		InventoryButton = if openDrawer ~= "Inventory"
			then e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),

				Position = UDim2.new(0, 24, 0.42, 0),

				Size = UDim2.fromOffset(buttonWidth, buttonHeight),

				BackgroundTransparency = 1,
				ZIndex = 25,
			}, {
				Button = e(HUDButton, {
					Text = "Stash",

					Icon = HUDAssets.Inventory,

					Color = Theme.Color.Bearings,

					Badge = if inventoryUnread > 0 then tostring(inventoryUnread) else nil,

					Size = UDim2.fromScale(1, 1),

					OnActivated = function()
						setOpenDrawer(if openDrawer == "Inventory" then "" else "Inventory")
					end,
				}),
			})
			else nil,

		WorkersButton = if openDrawer ~= "Workers"
			then e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),

				Position = UDim2.new(1, -24, 0.42, 0),

				Size = UDim2.fromOffset(buttonWidth, buttonHeight),

				BackgroundTransparency = 1,
				ZIndex = 25,
			}, {
				Button = e(HUDButton, {
					Text = "Workers",

					Icon = HUDAssets.Workers,

					Color = Theme.Color.Assembler,

					Badge = if workerUnread > 0 then tostring(workerUnread) else nil,

					Size = UDim2.fromScale(1, 1),

					OnActivated = function()
						setOpenDrawer(if openDrawer == "Workers" then "" else "Workers")
					end,
				}),
			})
			else nil,

		-- Bottom-left money
		MoneyStats = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),

			Position = UDim2.new(0, 16, 1, -18),

			Size = UDim2.fromOffset(statWidth, statHeight * 2 + 5),

			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 5),

				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			FactoryCash = e(StatDisplay, {
				Icon = HUDAssets.FactoryCash,

				Value = if hasFactory then `${NumberFormatUtil.Format(factoryCash)}` else "$0",

				Label = if hasFactory then "Factory Cash" else "No Factory",

				AccentColor = Theme.Color.Yellow,

				Compact = mobile,

				Size = UDim2.fromOffset(statWidth, statHeight),

				LayoutOrder = 1,
			}),

			PlayerCash = e(StatDisplay, {
				Icon = HUDAssets.PlayerCash,

				Value = `${NumberFormatUtil.Format(playerCash)}`,

				Label = "Player Cash",

				AccentColor = Theme.Color.Success,

				Compact = mobile,

				Size = UDim2.fromOffset(statWidth, statHeight),

				LayoutOrder = 2,
			}),
		}),

		-- Bottom-right automation
		AutomationStats = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),

			Position = UDim2.new(1, -16, 1, -18),

			Size = UDim2.fromOffset(statWidth, statHeight * 2 + 5),

			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 5),

				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Workers = e(StatDisplay, {
				Icon = HUDAssets.Workers,

				Value = `{placedWorkers} PLACED`,

				Label = `{totalWorkers} OWNED`,

				AccentColor = Theme.Color.Assembler,

				AlignRight = true,

				Compact = mobile,

				Size = UDim2.fromOffset(statWidth, statHeight),

				LayoutOrder = 1,
			}),

			Automation = e(StatDisplay, {
				Icon = HUDAssets.Automation,

				Value = `{NumberFormatUtil.Format(totalAutomation)}/MIN`,

				Label = "MAX OUTPUT",

				AccentColor = Theme.Color.Wheels,

				AlignRight = true,

				Compact = mobile,

				Size = UDim2.fromOffset(statWidth, statHeight),

				LayoutOrder = 2,
			}),
		}),

		-- Drawers
		InventoryDrawer = if openDrawer == "Inventory"
			then e(HUDDrawer, {
				Title = "Factory Stash",

				Icon = HUDAssets.Inventory,

				AccentColor = Theme.Color.Bearings,

				Side = "Left",

				Mobile = mobile,

				Width = drawerWidth,

				Height = drawerHeight,

				Content = inventoryContent,

				OnClose = function()
					setOpenDrawer("")
				end,
			})
			else nil,

		WorkersDrawer = if openDrawer == "Workers"
			then e(HUDDrawer, {
				Title = "Worker Crew",

				Icon = HUDAssets.Workers,

				AccentColor = Theme.Color.Assembler,

				Side = "Right",

				Mobile = mobile,

				Width = drawerWidth,

				Height = drawerHeight,

				Content = workerContent,

				OnClose = function()
					setOpenDrawer("")
				end,
			})
			else nil,
	})
end

return PassiveHUD
