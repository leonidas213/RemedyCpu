def lfsr(seed, taps):
    """Generate a sequence using a 16-bit LFSR with reversed taps (16 to 0)."""
    lfsr = seed
    period = 0
    while True:
        # XOR the tapped bits (using reversed bit numbering)
        feedback = 0
        for t in taps:
            feedback ^= (lfsr >> t) & 1
        # Shift the register and insert the feedback bit (now into the MSB)
        lfsr = (lfsr << 1) & 0xFFFF | feedback  # Mask to keep it 16-bit
        period += 1
        yield lfsr
        #if lfsr == seed:
        #    break


# Example usage
seed = 0x16  # Seed value (must be non-zero)
taps = [15, 13, 12, 10]  # Positions corresponding to the polynomial x^16 + x^14 + x^13 + x^11 + 1
#taps = [ 13, 9, 4]
lfsr_gen = lfsr(seed, taps)

# Generate and print the first 20 numbers
numberList=[]
periodic=False
for _ in range(65600):
    numberList.append(next(lfsr_gen))
    print(hex(numberList[-1]))

    for i in range(0, len(numberList)):
        if numberList[i] == numberList[-1] and i != len(numberList)-1:
            print("Period: ", len(numberList)-1)
            print("number1:", numberList[i])
            print("number2:", numberList[-1])
            periodic=True
            break
    if periodic:
        break
print(len(numberList))
numberList.sort()
#print numberlist as hex
for i in range(0, len(numberList)):
    print(hex(numberList[i]))