import { TooManyRequestsException } from "@nestjs/common";
import { TelegramBotService } from "../telegram-bot.service";
import { TelegramRepository } from "../telegram.repository";

describe("TelegramBotService", () => {
  it("rejects the correct code after the Telegram ID is locked out", async () => {
    const repository = {
      verifyVerificationCode: jest
        .fn()
        .mockResolvedValueOnce("invalid")
        .mockResolvedValueOnce("locked"),
    } as unknown as TelegramRepository;
    const service = new TelegramBotService(repository);

    await expect(service.verifyUser(123456789, "WRONG1")).resolves.toBe(false);
    await expect(service.verifyUser(123456789, "A1B2C3")).rejects.toThrow(
      TooManyRequestsException,
    );
    expect(repository.verifyVerificationCode).toHaveBeenCalledWith(
      123456789,
      "WRONG1",
    );
    expect(repository.verifyVerificationCode).toHaveBeenLastCalledWith(
      123456789,
      "A1B2C3",
    );
  });
});