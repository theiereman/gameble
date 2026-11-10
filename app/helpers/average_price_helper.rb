module AveragePriceHelper
  def average_price_basis(price)
    t("average_price.basis", count: price.sales_used) unless price.nil? || price.no_sale?
  end

  def average_price_words(price)
    return if price.nil?
    return t("average_price.words.no_sale") if price.no_sale?

    amount = t("picoin_amount.accessible", amount: picoins(price.average))
    t(price.few_sales? ? "average_price.words.few_sales" : "average_price.words.priced", amount:)
  end
end
