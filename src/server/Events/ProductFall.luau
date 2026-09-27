--!strict
-- Um produto cai sozinho da prateleira.

local CollectionService = game:GetService("CollectionService")

local ProductFall = {}

local function candidates(ctx: any): { BasePart }
	local list = {}
	for _, product in CollectionService:GetTagged("Product") do
		if product:IsA("BasePart") and product.Anchored and product:IsDescendantOf(ctx.Map) then
			table.insert(list, product)
		end
	end
	return list
end

function ProductFall.CanRun(ctx: any): boolean
	return #candidates(ctx) > 0
end

function ProductFall.Run(ctx: any)
	local product: BasePart = ctx.Rng:Pick(candidates(ctx))
	CollectionService:RemoveTag(product, "Product")
	product.Anchored = false
	product.AssemblyLinearVelocity = Vector3.new(ctx.Rng:Number(-6, 6), 3, ctx.Rng:Number(-6, 6))
	ctx.Services.Audio:PlayAt("ProductFall", product.Position)
	ctx.WitnessNear(product.Position, 35)
end

return ProductFall
